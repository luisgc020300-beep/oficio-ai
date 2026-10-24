// test/factura_model_test.dart
//
// Modelo Factura/PagoFactura en aislamiento, sin repositorio ni widgets:
// cálculo de totales (base, IVA, descuento), redondeo monetario, saldo
// pendiente y los tres estados derivados (pagada/pagada parcial/
// vencida), compatibilidad con JSON guardado antes de que existiera
// este modelo, y el campo esDemo (encargo iteración 5, sección 12,
// puntos 1, 2, 8, 12, 14 y 17).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/models/cliente_snapshot.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/factura_totals.dart';
import 'package:oficio_ai/data/models/pago_factura.dart';

Factura _facturaBase({
  List<ConceptoPresupuesto>? conceptos,
  double iva = 21,
  double descuento = 0,
  EstadoFactura estado = EstadoFactura.borrador,
  int? anio,
  int? numeroSecuencial,
  DateTime? fechaEmision,
  DateTime? fechaVencimiento,
  List<PagoFactura> pagos = const [],
  ClienteSnapshot? datosCliente,
  TipoDocumentoFactura tipoDocumento = TipoDocumentoFactura.ordinaria,
  String serie = '',
  String? facturaOriginalId,
  String? motivoRectificacion,
  ModalidadRectificacion? modalidadRectificacion,
  double? importeRectificacion,
}) => Factura(
  id: 'f1',
  clienteId: 'c1',
  titulo: 'Factura de prueba',
  conceptos:
      conceptos ??
      const [
        ConceptoPresupuesto(
          id: 'c1',
          descripcion: 'Mano de obra',
          cantidad: 2,
          precioUnitario: 35,
        ),
      ],
  ivaPorcentaje: iva,
  descuentoPorcentaje: descuento,
  estado: estado,
  anio: anio,
  numeroSecuencial: numeroSecuencial,
  creadaEl: DateTime(2026, 1, 1),
  fechaEmision: fechaEmision,
  fechaVencimiento: fechaVencimiento,
  pagos: pagos,
  datosCliente: datosCliente,
  tipoDocumento: tipoDocumento,
  serie: serie,
  facturaOriginalId: facturaOriginalId,
  motivoRectificacion: motivoRectificacion,
  modalidadRectificacion: modalidadRectificacion,
  importeRectificacion: importeRectificacion,
);

void main() {
  group('calcularTotalesFactura -- base, IVA, descuento y redondeo', () {
    test('sin descuento: base = subtotal, IVA sobre la base', () {
      final totales = calcularTotalesFactura(
        const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Pieza',
            cantidad: 3,
            precioUnitario: 10,
          ),
        ],
        21,
        0,
      );
      expect(totales.subtotalBruto, 30);
      expect(totales.descuento, 0);
      expect(totales.baseImponible, 30);
      expect(totales.iva, 6.3);
      expect(totales.total, 36.3);
    });

    test('el descuento se aplica sobre el subtotal, antes del IVA -- '
        'nunca sobre el total ya con impuestos', () {
      final totales = calcularTotalesFactura(
        const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 100,
          ),
        ],
        21,
        10,
      );
      expect(totales.subtotalBruto, 100);
      expect(totales.descuento, 10);
      expect(totales.baseImponible, 90);
      expect(totales.iva, 18.9);
      expect(totales.total, 108.9);
    });

    test('redondeo a 2 decimales: el total nunca difiere de la suma de '
        'sus partes ya redondeadas', () {
      final totales = calcularTotalesFactura(
        const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Horas',
            cantidad: 1,
            precioUnitario: 33.333,
          ),
        ],
        21,
        0,
      );
      expect(totales.total, totales.baseImponible + totales.iva);
      // redondear2 usa .round(), no trunca -- 33.333 -> 33.33.
      expect(totales.baseImponible, 33.33);
    });

    test('sin conceptos, todos los totales son cero', () {
      final totales = calcularTotalesFactura([], 21, 0);
      expect(totales.subtotalBruto, 0);
      expect(totales.total, 0);
    });
  });

  group('Factura.numero', () {
    test('null mientras es borrador (sin año ni secuencial asignados)', () {
      expect(_facturaBase().numero, isNull);
    });

    test('formato AAAA-NNNN con el secuencial a 4 dígitos', () {
      final f = _facturaBase(anio: 2026, numeroSecuencial: 7);
      expect(f.numero, '2026-0007');
    });
  });

  group('saldoPendiente / pagadaCompleta / pagadaParcial', () {
    test('una factura recién emitida sin cobros está pendiente del total', () {
      final f = _facturaBase(estado: EstadoFactura.emitida);
      // Total = 2 * 35 * 1.21 = 84.7
      expect(f.totales.total, 84.7);
      expect(f.saldoPendiente, 84.7);
      expect(f.pagadaCompleta, isFalse);
      expect(f.pagadaParcial, isFalse);
    });

    test('un pago parcial reduce el saldo sin marcarla como pagada', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 2),
            importe: 50,
            registradoEl: DateTime(2026, 2),
          ),
        ],
      );
      expect(f.saldoPendiente, 34.7);
      expect(f.pagadaParcial, isTrue);
      expect(f.pagadaCompleta, isFalse);
    });

    test('el pago que cubre el total completo salda la factura a cero y '
        'la marca como pagada', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 2),
            importe: 84.7,
            registradoEl: DateTime(2026, 2),
          ),
        ],
      );
      expect(f.saldoPendiente, 0);
      expect(f.pagadaCompleta, isTrue);
      expect(f.pagadaParcial, isFalse);
    });

    test('varios pagos parciales se acumulan correctamente', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 2, 1),
            importe: 30,
            registradoEl: DateTime(2026, 2, 1),
          ),
          PagoFactura(
            id: 'p2',
            fecha: DateTime(2026, 2, 5),
            importe: 54.7,
            registradoEl: DateTime(2026, 2, 5),
          ),
        ],
      );
      expect(f.totalCobrado, 84.7);
      expect(f.saldoPendiente, 0);
      expect(f.pagadaCompleta, isTrue);
    });

    test('un borrador o una anulada nunca se consideran pagadas, aunque '
        'tuvieran pagos registrados', () {
      final borrador = _facturaBase();
      expect(borrador.pagadaCompleta, isFalse);

      final anulada = _facturaBase(estado: EstadoFactura.anulada);
      expect(anulada.pagadaCompleta, isFalse);
    });
  });

  group('estaVencida()', () {
    test('no vencida si no tiene fecha de vencimiento', () {
      final f = _facturaBase(estado: EstadoFactura.emitida);
      expect(f.estaVencida(ahora: DateTime(2030)), isFalse);
    });

    test('vencida si la fecha de vencimiento ya pasó y sigue sin cobrar', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        fechaVencimiento: DateTime(2026, 1, 10),
      );
      expect(f.estaVencida(ahora: DateTime(2026, 1, 20)), isTrue);
      expect(f.estaVencida(ahora: DateTime(2026, 1, 5)), isFalse);
    });

    test('una factura ya pagada no se considera vencida aunque la fecha '
        'de vencimiento haya pasado', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        fechaVencimiento: DateTime(2026, 1, 10),
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 1, 2),
            importe: 84.7,
            registradoEl: DateTime(2026, 1, 2),
          ),
        ],
      );
      expect(f.estaVencida(ahora: DateTime(2026, 2, 1)), isFalse);
    });

    test('un borrador nunca está vencido', () {
      final f = _facturaBase(fechaVencimiento: DateTime(2020, 1, 1));
      expect(f.estaVencida(ahora: DateTime(2030)), isFalse);
    });
  });

  group('esDemo y compatibilidad JSON', () {
    test('false por defecto y persiste true/false en el ciclo toJson/fromJson', () {
      final real = _facturaBase(estado: EstadoFactura.emitida, anio: 2026, numeroSecuencial: 1);
      expect(real.esDemo, isFalse);

      final demo = Factura(
        id: 'd1',
        clienteId: 'c1',
        titulo: 'Demo',
        conceptos: const [],
        creadaEl: DateTime(2026),
        esDemo: true,
      );
      expect(Factura.fromJson(demo.toJson()).esDemo, isTrue);
    });

    test('un pago sobrevive el ciclo toJson/fromJson con todos sus campos', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 3,
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 3, 4),
            importe: 20,
            metodo: MetodoPago.bizum,
            nota: 'Mitad por Bizum',
            registradoEl: DateTime(2026, 3, 4, 10, 30),
          ),
        ],
      );
      final restaurada = Factura.fromJson(f.toJson());
      expect(restaurada.pagos, hasLength(1));
      expect(restaurada.pagos.first.importe, 20);
      expect(restaurada.pagos.first.metodo, MetodoPago.bizum);
      expect(restaurada.pagos.first.nota, 'Mitad por Bizum');
      expect(restaurada.numero, '2026-0003');
    });

    test('un JSON guardado antes de que existiera este modelo (solo los '
        'campos imprescindibles) se lee sin lanzar, con los valores por '
        'defecto esperados', () {
      final jsonAntiguo = {
        'id': '1',
        'clienteId': 'c1',
        'titulo': 'Factura mínima',
        'conceptos': <Map<String, dynamic>>[],
        'estado': 'emitida',
        'creadaEl': DateTime(2026).toIso8601String(),
        // Sin ivaPorcentaje, descuentoPorcentaje, anio, numeroSecuencial,
        // fechaEmision, pagos, esDemo, datosEmisor ni datosCliente --
        // así se guardaba antes de que existiera cada campo.
      };
      final f = Factura.fromJson(jsonAntiguo);
      expect(f.ivaPorcentaje, 21);
      expect(f.descuentoPorcentaje, 0);
      expect(f.numero, isNull);
      expect(f.pagos, isEmpty);
      expect(f.esDemo, isFalse);
      expect(f.saldoPendiente, 0);
      // Ni el emisor ni el cliente se rellenan con nada por defecto --
      // una ausencia en el JSON antiguo se queda en null, nunca se
      // sustituye en silencio (iteración 6/7.1).
      expect(f.datosEmisor, isNull);
      expect(f.datosCliente, isNull);
    });

    test('datosCliente sobrevive el ciclo toJson/fromJson con todos sus '
        'campos (iteración 7.1/7.2)', () {
      const snapshot = ClienteSnapshot(
        nombre: 'Ana Rodríguez Jiménez',
        telefono: '611 222 333',
        email: 'ana@email.com',
        direccion: 'Avenida de España 22, Getafe',
      );
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 1,
        datosCliente: snapshot,
      );
      final restaurada = Factura.fromJson(f.toJson());
      expect(restaurada.datosCliente?.nombre, 'Ana Rodríguez Jiménez');
      expect(restaurada.datosCliente?.telefono, '611 222 333');
      expect(restaurada.datosCliente?.email, 'ana@email.com');
      expect(restaurada.datosCliente?.direccion, 'Avenida de España 22, Getafe');
    });
  });

  group('rectificativas (iteración 8)', () {
    test('una factura ordinaria tiene tipoDocumento ordinaria y serie '
        'vacía por defecto -- numero no cambia de formato', () {
      final f = _facturaBase(estado: EstadoFactura.emitida, anio: 2026, numeroSecuencial: 7);
      expect(f.tipoDocumento, TipoDocumentoFactura.ordinaria);
      expect(f.serie, '');
      expect(f.numero, '2026-0007');
    });

    test('una rectificativa antepone la serie "R" al número', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 3,
        serie: serieRectificativas,
        tipoDocumento: TipoDocumentoFactura.rectificativa,
        facturaOriginalId: 'original-1',
        motivoRectificacion: 'Error en el IVA aplicado',
        modalidadRectificacion: ModalidadRectificacion.porDiferencias,
      );
      expect(f.numero, 'R-2026-0003');
    });

    test('la relación con la factura original, el motivo y la modalidad '
        'sobreviven el ciclo toJson/fromJson', () {
      final f = _facturaBase(
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 1,
        serie: serieRectificativas,
        tipoDocumento: TipoDocumentoFactura.rectificativa,
        facturaOriginalId: 'original-1',
        motivoRectificacion: 'Descuento no aplicado',
        modalidadRectificacion: ModalidadRectificacion.importeResultante,
        importeRectificacion: -12.5,
      );
      final restaurada = Factura.fromJson(f.toJson());
      expect(restaurada.tipoDocumento, TipoDocumentoFactura.rectificativa);
      expect(restaurada.serie, serieRectificativas);
      expect(restaurada.facturaOriginalId, 'original-1');
      expect(restaurada.motivoRectificacion, 'Descuento no aplicado');
      expect(restaurada.modalidadRectificacion, ModalidadRectificacion.importeResultante);
      expect(restaurada.importeRectificacion, -12.5);
    });

    test('un JSON de antes de la iteración 8 (sin ninguno de estos '
        'campos) se lee como factura ordinaria, sin relación de '
        'rectificación -- nunca se infiere ninguna', () {
      final jsonAntiguo = {
        'id': '1',
        'clienteId': 'c1',
        'titulo': 'Factura mínima',
        'conceptos': <Map<String, dynamic>>[],
        'estado': 'emitida',
        'anio': 2026,
        'numeroSecuencial': 5,
        'creadaEl': DateTime(2026).toIso8601String(),
      };
      final f = Factura.fromJson(jsonAntiguo);
      expect(f.tipoDocumento, TipoDocumentoFactura.ordinaria);
      expect(f.serie, '');
      expect(f.numero, '2026-0005'); // mismo formato de siempre
      expect(f.facturaOriginalId, isNull);
      expect(f.motivoRectificacion, isNull);
      expect(f.modalidadRectificacion, isNull);
      expect(f.importeRectificacion, isNull);
    });

    test('calcularImporteRectificacion es la resta de los totales ya '
        'calculados, con su signo -- una reducción da negativo', () {
      expect(
        calcularImporteRectificacion(totalOriginal: 121, totalCorregido: 90.75),
        -30.25,
      );
      expect(
        calcularImporteRectificacion(totalOriginal: 100, totalCorregido: 150),
        50,
      );
    });

    test('una rectificativa nunca tiene saldo pendiente, aunque su '
        'propio total (modalidad importe resultante) sea positivo -- '
        'el cobro sigue viviendo en la factura original', () {
      final f = _facturaBase(
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio corregido',
            cantidad: 1,
            precioUnitario: 200,
          ),
        ],
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 1,
        tipoDocumento: TipoDocumentoFactura.rectificativa,
        serie: serieRectificativas,
        facturaOriginalId: 'original-1',
        modalidadRectificacion: ModalidadRectificacion.importeResultante,
        importeRectificacion: 50,
      );
      expect(f.totales.total, greaterThan(0)); // el total del documento sí es positivo
      expect(f.saldoPendiente, 0);
      expect(f.pagadaCompleta, isTrue);
    });

    test('importeFacturacion: en "por diferencias" coincide con el '
        'total del documento; en "importe resultante" usa la '
        'diferencia guardada, no el total completo -- evita la doble '
        'contabilización en los indicadores agregados', () {
      final porDiferencias = _facturaBase(
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Corrección',
            cantidad: 1,
            precioUnitario: -30,
          ),
        ],
        descuento: 0,
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 1,
        tipoDocumento: TipoDocumentoFactura.rectificativa,
        serie: serieRectificativas,
        facturaOriginalId: 'original-1',
        modalidadRectificacion: ModalidadRectificacion.porDiferencias,
      );
      expect(porDiferencias.importeFacturacion, porDiferencias.totales.total);

      final importeResultante = _facturaBase(
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio corregido',
            cantidad: 1,
            precioUnitario: 90,
          ),
        ],
        estado: EstadoFactura.emitida,
        anio: 2026,
        numeroSecuencial: 2,
        tipoDocumento: TipoDocumentoFactura.rectificativa,
        serie: serieRectificativas,
        facturaOriginalId: 'original-1',
        modalidadRectificacion: ModalidadRectificacion.importeResultante,
        importeRectificacion: -36.3,
      );
      expect(importeResultante.importeFacturacion, -36.3);
      expect(importeResultante.importeFacturacion, isNot(importeResultante.totales.total));
    });

    test('una factura ordinaria usa siempre su propio total en '
        'importeFacturacion, nunca importeRectificacion (que ni '
        'siquiera tiene)', () {
      final f = _facturaBase(estado: EstadoFactura.emitida, anio: 2026, numeroSecuencial: 1);
      expect(f.importeFacturacion, f.totales.total);
    });
  });
}
