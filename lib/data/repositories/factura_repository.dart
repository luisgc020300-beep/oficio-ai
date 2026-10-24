// lib/data/repositories/factura_repository.dart
//
// A diferencia de los demás repositorios (cliente/trabajo/presupuesto/
// cita), este no expone un update() genérico libre: las reglas de
// integridad de una factura (numeración correlativa sin huecos ni
// duplicados, trazabilidad de una factura ya emitida, pagos de
// solo-anexado) viven aquí para que no dependan de que cada pantalla las
// recuerde aplicar.
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../models/cliente_snapshot.dart';
import '../models/datos_negocio.dart';
import '../models/factura.dart';
import '../models/factura_totals.dart';
import '../models/pago_factura.dart';

class FacturaRepository extends ChangeNotifier {
  FacturaRepository(this._store);

  static const _key = 'oficio_ai.facturas';

  final LocalStore _store;
  List<Factura> _facturas = [];

  List<Factura> get facturas => List.unmodifiable(_facturas);

  List<Factura> porCliente(String clienteId) =>
      _facturas.where((f) => f.clienteId == clienteId).toList();

  List<Factura> porTrabajo(String trabajoId) =>
      _facturas.where((f) => f.trabajoId == trabajoId).toList();

  List<Factura> porPresupuesto(String presupuestoId) =>
      _facturas.where((f) => f.presupuestoId == presupuestoId).toList();

  Factura? byId(String id) {
    for (final f in _facturas) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Rectificativas que referencian [facturaOriginalId] -- el lado
  /// "hacia delante" del historial original/rectificativa (iteración
  /// 8); el lado "hacia atrás" es simplemente
  /// `byId(factura.facturaOriginalId)`. No hay límite de cuántas puede
  /// haber: corregir una rectificativa anterior es un caso real, no se
  /// bloquea aquí.
  List<Factura> rectificativasDe(String facturaOriginalId) => _facturas
      .where(
        (f) =>
            f.tipoDocumento == TipoDocumentoFactura.rectificativa &&
            f.facturaOriginalId == facturaOriginalId,
      )
      .toList();

  Future<void> load() async {
    final raw = _store.readList(_key);
    _facturas = raw.map(Factura.fromJson).toList()
      ..sort((a, b) => b.creadaEl.compareTo(a.creadaEl));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Factura> seed) async {
    if (_facturas.isNotEmpty) return;
    _facturas = [...seed]..sort((a, b) => b.creadaEl.compareTo(a.creadaEl));
    await _persist();
    notifyListeners();
  }

  /// Crea un borrador -- también el de una rectificativa (iteración 8):
  /// no hace falta un método aparte, se reutiliza esta misma vía y
  /// luego emitir() de siempre, igual que una factura ordinaria. Lo
  /// único distinto es la validación de abajo, exclusiva de
  /// rectificativas: referenciar una factura inexistente, o una que
  /// todavía no se ha emitido, se rechaza aquí mismo -- nunca se llega
  /// a guardar un borrador con una relación que no se pueda honrar.
  /// Como ninguna factura emitida puede borrarse después (ver
  /// delete()/anular()), una vez superada esta comprobación la relación
  /// no puede romperse por nada que el repositorio permita hacer.
  Future<void> add(Factura factura) async {
    if (factura.estado != EstadoFactura.borrador) {
      throw StateError('Una factura nueva solo puede crearse como borrador.');
    }
    var aGuardar = factura;
    if (factura.tipoDocumento == TipoDocumentoFactura.rectificativa) {
      final originalId = factura.facturaOriginalId;
      if (originalId == null || originalId.trim().isEmpty) {
        throw StateError(
          'Una rectificativa debe indicar la factura que corrige.',
        );
      }
      final original = byId(originalId);
      if (original == null) {
        throw StateError('La factura original a rectificar ya no existe.');
      }
      if (original.estado != EstadoFactura.emitida) {
        throw StateError(
          'Solo se puede rectificar una factura ya emitida.',
        );
      }
      // El importe de la rectificación se calcula aquí, nunca se
      // confía en lo que pase quien llama -- mismo criterio que
      // numeroSecuencial en emitir(). Solo aplica a la modalidad que
      // declara el importe YA corregido (ver Factura.importeFacturacion
      // sobre por qué, si no, se contaría la operación dos veces en los
      // indicadores agregados).
      if (factura.modalidadRectificacion == ModalidadRectificacion.importeResultante) {
        aGuardar = factura.copyWith(
          importeRectificacion: calcularImporteRectificacion(
            totalOriginal: original.totales.total,
            totalCorregido: factura.totales.total,
          ),
        );
      }
    }
    await _guardar([..._facturas, aGuardar]);
  }

  /// Solo permite editar una factura mientras es borrador -- una vez
  /// emitida, sus datos fiscales (conceptos, IVA, número...) ya no
  /// cambian por esta vía (encargo, sección 5: "no permitas editar
  /// silenciosamente una factura ya emitida"). Los cambios de estado
  /// pasan por emitir()/anular(); los cobros, por registrarPago().
  Future<void> update(Factura factura) async {
    final actual = byId(factura.id);
    if (actual == null) {
      throw StateError('Esta factura ya no existe.');
    }
    if (actual.estado != EstadoFactura.borrador) {
      throw StateError('No se puede editar una factura ya emitida.');
    }
    if (factura.estado != EstadoFactura.borrador) {
      throw StateError('Usa emitir() para cambiar el estado de una factura.');
    }
    await _guardar(
      _facturas.map((f) => f.id == factura.id ? factura : f).toList(),
    );
  }

  /// Solo se puede borrar un borrador: una factura ya emitida se
  /// conserva siempre, aunque sea anulándola (ver anular()), para no
  /// perder su rastro fiscal.
  Future<void> delete(String id) async {
    final actual = byId(id);
    if (actual == null) return;
    if (actual.estado != EstadoFactura.borrador) {
      throw StateError(
        'No se puede eliminar una factura ya emitida. Anúlala en su lugar.',
      );
    }
    await _guardar(_facturas.where((f) => f.id != id).toList());
  }

  /// Asigna número y fecha de emisión y pasa la factura a "emitida".
  /// El correlativo se calcula aquí, nunca lo elige quien llama, para
  /// que sea imposible pedir dos veces el mismo número por error: se
  /// toma el máximo ya usado dentro del mismo año Y LA MISMA SERIE
  /// (iteración 8 -- antes solo importaba el año, pero una
  /// rectificativa necesita su propia secuencia dentro de
  /// [serieRectificativas], sin compartirla con las facturas
  /// ordinarias ni dejar que las interrumpa; ver Factura.serie) y se
  /// suma 1. Al no numerarse los borradores, descartar uno nunca deja
  /// un hueco. Esto no cambia el comportamiento de las facturas
  /// ordinarias ya existentes: su serie siempre ha sido '', así que el
  /// conjunto que se compara es el mismo que antes.
  /// [datosEmisor] se exige completo (ver DatosNegocio.listoParaFacturar)
  /// porque es el respaldo de última instancia de la regla de negocio
  /// "sin datos del emisor no se emite" -- la pantalla ya hace esta
  /// misma comprobación antes para poder explicar qué falta y llevar a
  /// "Mi negocio" (encargo iteración 6, sección 6), pero aquí se vuelve
  /// a exigir para que ningún otro punto de la app pueda saltársela.
  /// Se guarda tal cual, como fotografía -- ver Factura.datosEmisor.
  ///
  /// [datosCliente] (iteración 7.1) es opcional y nunca bloquea la
  /// emisión -- a diferencia del emisor, no hay una pantalla de
  /// "completar datos del cliente" a la que mandar al usuario; si el
  /// cliente fue borrado antes de emitir, sencillamente no hay
  /// fotografía que guardar (ver Factura.datosCliente).
  Future<Factura> emitir(
    String id, {
    required DatosNegocio datosEmisor,
    ClienteSnapshot? datosCliente,
    DateTime? fechaVencimiento,
  }) async {
    final actual = byId(id);
    if (actual == null) {
      throw StateError('Esta factura ya no existe.');
    }
    if (actual.estado != EstadoFactura.borrador) {
      throw StateError('Esta factura ya ha sido emitida.');
    }
    if (actual.conceptos.isEmpty) {
      throw StateError('Añade al menos un concepto antes de emitir.');
    }
    if (!datosEmisor.listoParaFacturar) {
      throw StateError(
        'Completa los datos de tu negocio antes de emitir: '
        '${datosEmisor.camposFaltantesParaFacturar.join(', ')}.',
      );
    }
    if (actual.tipoDocumento == TipoDocumentoFactura.rectificativa &&
        (actual.motivoRectificacion?.trim().isEmpty ?? true)) {
      throw StateError(
        'Indica el motivo de la rectificación antes de emitirla.',
      );
    }
    final ahora = DateTime.now();
    final anio = ahora.year;
    final siguiente =
        _facturas
            .where(
              (f) =>
                  f.anio == anio &&
                  f.serie == actual.serie &&
                  f.numeroSecuencial != null,
            )
            .map((f) => f.numeroSecuencial!)
            .fold<int>(0, (max, n) => n > max ? n : max) +
        1;
    final emitida = actual.copyWith(
      estado: EstadoFactura.emitida,
      anio: anio,
      numeroSecuencial: siguiente,
      fechaEmision: ahora,
      fechaVencimiento: fechaVencimiento,
      datosEmisor: datosEmisor,
      datosCliente: datosCliente,
    );
    await _guardar(_facturas.map((f) => f.id == id ? emitida : f).toList());
    return emitida;
  }

  /// Anula una factura ya emitida sin borrarla ni reutilizar su número
  /// (encargo, sección 5) -- si hace falta facturar de nuevo, se crea
  /// una factura nueva, que recibirá el siguiente correlativo.
  Future<Factura> anular(String id, String motivo) async {
    if (motivo.trim().isEmpty) {
      throw ArgumentError('El motivo de anulación es obligatorio.');
    }
    final actual = byId(id);
    if (actual == null) {
      throw StateError('Esta factura ya no existe.');
    }
    if (actual.estado != EstadoFactura.emitida) {
      throw StateError('Solo se puede anular una factura emitida.');
    }
    final anulada = actual.copyWith(
      estado: EstadoFactura.anulada,
      motivoAnulacion: motivo.trim(),
      fechaAnulacion: DateTime.now(),
    );
    await _guardar(_facturas.map((f) => f.id == id ? anulada : f).toList());
    return anulada;
  }

  /// Registra un cobro. Rechaza (no recorta en silencio) un importe
  /// mayor que el saldo pendiente, y nunca modifica ni borra un pago ya
  /// registrado -- la lista de pagos es de solo-anexado.
  Future<Factura> registrarPago(
    String facturaId, {
    required DateTime fecha,
    required double importe,
    MetodoPago metodo = MetodoPago.otro,
    String? nota,
  }) async {
    final actual = byId(facturaId);
    if (actual == null) {
      throw StateError('Esta factura ya no existe.');
    }
    if (actual.estado != EstadoFactura.emitida) {
      throw StateError('Solo se pueden registrar cobros en facturas emitidas.');
    }
    if (actual.tipoDocumento == TipoDocumentoFactura.rectificativa) {
      throw StateError(
        'Una rectificativa no registra cobros propios -- gestiona el '
        'cobro sobre la factura original.',
      );
    }
    if (importe <= 0) {
      throw ArgumentError('El importe del pago debe ser mayor que cero.');
    }
    // Pequeño margen (medio céntimo) para no rechazar por ruido de coma
    // flotante un pago que en la práctica salda exactamente la factura.
    if (importe - actual.saldoPendiente > 0.005) {
      throw ArgumentError(
        'El importe no puede superar el saldo pendiente '
        '(${actual.saldoPendiente.toStringAsFixed(2)} €).',
      );
    }
    final pago = PagoFactura(
      id: const Uuid().v4(),
      fecha: fecha,
      importe: importe,
      metodo: metodo,
      nota: (nota?.trim().isEmpty ?? true) ? null : nota!.trim(),
      registradoEl: DateTime.now(),
    );
    final actualizada = actual.copyWith(pagos: [...actual.pagos, pago]);
    await _guardar(
      _facturas.map((f) => f.id == facturaId ? actualizada : f).toList(),
    );
    return actualizada;
  }

  /// Si falla la escritura en disco (p. ej. el almacenamiento está
  /// lleno), el estado en memoria vuelve a como estaba antes -- nunca
  /// se queda con una factura "emitida" en memoria que en realidad no
  /// se llegó a guardar (iteración 7.1, sección 2: "evita que la
  /// factura quede marcada como emitida pero [la persistencia] no se
  /// guarde"). No es una transacción de verdad -- SharedPreferences no
  /// ofrece eso -- pero sí evita que memoria y disco diverjan en el
  /// único punto donde todas las escrituras de este repositorio pasan.
  Future<void> _guardar(List<Factura> nuevaLista) async {
    final anterior = _facturas;
    _facturas = nuevaLista..sort((a, b) => b.creadaEl.compareTo(a.creadaEl));
    try {
      await _persist();
    } catch (_) {
      _facturas = anterior;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _facturas.map((f) => f.toJson()).toList());
}
