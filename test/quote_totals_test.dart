// test/quote_totals_test.dart
//
// Cálculo de presupuestos (sección 6 del encargo) -- aislado de
// repositorios y widgets, prueba solo la función pura.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/quote_totals.dart';

void main() {
  group('calcularTotales', () {
    test('un solo concepto, IVA 21%', () {
      final totales = calcularTotales(const [
        ConceptoPresupuesto(
          id: '1',
          descripcion: 'Mano de obra',
          cantidad: 2,
          precioUnitario: 35,
        ),
      ], 21);

      expect(totales.subtotal, 70.0);
      expect(totales.iva, 14.7);
      expect(totales.total, 84.7);
    });

    test('varios conceptos suman subtotales individuales', () {
      final totales = calcularTotales(const [
        ConceptoPresupuesto(
          id: '1',
          descripcion: 'Material',
          cantidad: 3,
          precioUnitario: 12.5,
        ),
        ConceptoPresupuesto(
          id: '2',
          descripcion: 'Mano de obra',
          cantidad: 1,
          precioUnitario: 50,
        ),
      ], 10);

      // subtotal = 37.5 + 50 = 87.5
      expect(totales.subtotal, 87.5);
      expect(totales.iva, 8.75);
      expect(totales.total, 96.25);
    });

    test('sin conceptos, todo a cero', () {
      final totales = calcularTotales(const [], 21);
      expect(totales.subtotal, 0);
      expect(totales.iva, 0);
      expect(totales.total, 0);
    });

    test('IVA al 0% no añade nada', () {
      final totales = calcularTotales(const [
        ConceptoPresupuesto(
          id: '1',
          descripcion: 'Servicio exento',
          cantidad: 1,
          precioUnitario: 100,
        ),
      ], 0);
      expect(totales.subtotal, 100.0);
      expect(totales.iva, 0.0);
      expect(totales.total, 100.0);
    });

    test('redondea a 2 decimales en cantidades con decimales largos', () {
      final totales = calcularTotales(const [
        ConceptoPresupuesto(
          id: '1',
          descripcion: 'Horas fraccionadas',
          cantidad: 1.333,
          precioUnitario: 33.333,
        ),
      ], 21);
      // subtotal real = 44.432889 -> redondeado a 44.43
      expect(totales.subtotal, 44.43);
    });

    test('el subtotal de un concepto es cantidad x precio', () {
      const concepto = ConceptoPresupuesto(
        id: '1',
        descripcion: 'Azulejos',
        cantidad: 15,
        precioUnitario: 4.2,
      );
      expect(concepto.subtotal, 63.0);
    });
  });
}
