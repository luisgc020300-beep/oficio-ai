// test/factura_model_test.dart
//
// Modelo Factura/PagoFactura en aislamiento, sin repositorio ni widgets:
// cálculo de totales (base, IVA, descuento), redondeo monetario, saldo
// pendiente y los tres estados derivados (pagada/pagada parcial/
// vencida), compatibilidad con JSON guardado antes de que existiera
// este modelo, y el campo esDemo (encargo iteración 5, sección 12,
// puntos 1, 2, 8, 12, 14 y 17).
import 'package:flutter_test/flutter_test.dart';
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
        // fechaEmision, pagos ni esDemo.
      };
      final f = Factura.fromJson(jsonAntiguo);
      expect(f.ivaPorcentaje, 21);
      expect(f.descuentoPorcentaje, 0);
      expect(f.numero, isNull);
      expect(f.pagos, isEmpty);
      expect(f.esDemo, isFalse);
      expect(f.saldoPendiente, 0);
    });
  });
}
