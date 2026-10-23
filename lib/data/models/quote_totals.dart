// lib/data/models/quote_totals.dart
//
// Cálculo de totales de un presupuesto, aislado en una función pura para
// poder testearlo sin construir ningún widget ni repositorio (sección 6
// del encargo: pruebas unitarias para los cálculos de presupuestos).
import 'concepto_presupuesto.dart';

class QuoteTotals {
  const QuoteTotals({
    required this.subtotal,
    required this.iva,
    required this.total,
  });

  final double subtotal;
  final double iva;
  final double total;
}

double _redondear2(double v) => (v * 100).round() / 100;

QuoteTotals calcularTotales(
  List<ConceptoPresupuesto> conceptos,
  double ivaPorcentaje,
) {
  final subtotal = conceptos.fold<double>(0, (acc, c) => acc + c.subtotal);
  final iva = subtotal * (ivaPorcentaje / 100);
  return QuoteTotals(
    subtotal: _redondear2(subtotal),
    iva: _redondear2(iva),
    total: _redondear2(subtotal + iva),
  );
}
