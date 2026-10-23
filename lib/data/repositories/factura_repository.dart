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
import '../models/datos_negocio.dart';
import '../models/factura.dart';
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

  Future<void> add(Factura factura) async {
    if (factura.estado != EstadoFactura.borrador) {
      throw StateError('Una factura nueva solo puede crearse como borrador.');
    }
    await _guardar([..._facturas, factura]);
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
  /// toma el máximo ya usado en el año de emisión y se suma 1. Al no
  /// numerarse los borradores, descartar uno nunca deja un hueco.
  /// [datosEmisor] se exige completo (ver DatosNegocio.listoParaFacturar)
  /// porque es el respaldo de última instancia de la regla de negocio
  /// "sin datos del emisor no se emite" -- la pantalla ya hace esta
  /// misma comprobación antes para poder explicar qué falta y llevar a
  /// "Mi negocio" (encargo iteración 6, sección 6), pero aquí se vuelve
  /// a exigir para que ningún otro punto de la app pueda saltársela.
  /// Se guarda tal cual, como fotografía -- ver Factura.datosEmisor.
  Future<Factura> emitir(
    String id, {
    required DatosNegocio datosEmisor,
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
    final ahora = DateTime.now();
    final anio = ahora.year;
    final siguiente =
        _facturas
            .where((f) => f.anio == anio && f.numeroSecuencial != null)
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

  Future<void> _guardar(List<Factura> nuevaLista) async {
    _facturas = nuevaLista..sort((a, b) => b.creadaEl.compareTo(a.creadaEl));
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _facturas.map((f) => f.toJson()).toList());
}
