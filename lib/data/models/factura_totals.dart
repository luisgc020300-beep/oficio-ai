// lib/data/models/factura_totals.dart
//
// Cálculo de totales de una factura: base imponible, IVA y total, con
// descuento opcional aplicado antes de calcular el IVA (nunca sobre el
// total ya con impuestos). Misma estrategia monetaria que
// quote_totals.dart -- redondeo a 2 decimales en cada paso de la
// agregación, para que el total final nunca difiera de la suma de sus
// partes ya redondeadas (lo que vería el cliente en el PDF/pantalla).
//
// No se usa aritmética de enteros (céntimos) porque el resto del
// proyecto ya trabaja en double con este mismo redondeo (ver
// quote_totals.dart) -- introducir una estrategia distinta solo para
// facturas generaría dos formas de calcular dinero en la misma app.
import 'concepto_presupuesto.dart';

class FacturaTotals {
  const FacturaTotals({
    required this.subtotalBruto,
    required this.descuento,
    required this.baseImponible,
    required this.iva,
    required this.total,
  });

  final double subtotalBruto;
  final double descuento;
  final double baseImponible;
  final double iva;
  final double total;
}

double redondear2(double v) => (v * 100).round() / 100;

/// Importe neto de una rectificativa en modalidad
/// [ModalidadRectificacion.importeResultante] (iteración 8, art. 15.5 RD
/// 1619/2012): no es una fórmula fiscal nueva, es la resta de dos
/// totales que ya salen de [calcularTotalesFactura] -- la norma exige
/// que, aunque esta modalidad consigne el importe YA corregido en vez
/// de la diferencia, se "señale igualmente el importe de la
/// rectificación".
double calcularImporteRectificacion({
  required double totalOriginal,
  required double totalCorregido,
}) => redondear2(totalCorregido - totalOriginal);

FacturaTotals calcularTotalesFactura(
  List<ConceptoPresupuesto> conceptos,
  double ivaPorcentaje,
  double descuentoPorcentaje,
) {
  final subtotalBruto = conceptos.fold<double>(0, (acc, c) => acc + c.subtotal);
  final descuento = redondear2(subtotalBruto * (descuentoPorcentaje / 100));
  final baseImponible = redondear2(subtotalBruto - descuento);
  final iva = redondear2(baseImponible * (ivaPorcentaje / 100));
  return FacturaTotals(
    subtotalBruto: redondear2(subtotalBruto),
    descuento: descuento,
    baseImponible: baseImponible,
    iva: iva,
    total: redondear2(baseImponible + iva),
  );
}
