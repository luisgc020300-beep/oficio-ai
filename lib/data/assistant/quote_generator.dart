// lib/data/assistant/quote_generator.dart
//
// Contrato único para "convertir una descripción en una propuesta de
// presupuesto". Hoy solo hay una implementación (LocalQuoteGenerator,
// reglas locales, sin red). El día que haya un proveedor de IA real,
// esa nueva clase implementa esta misma interfaz y se cambia solo el
// punto donde se instancia -- ni assisted_quote_screen.dart ni
// quote_form_screen.dart ni el repositorio tienen que cambiar.
import 'propuesta_presupuesto.dart';

abstract class QuoteGenerator {
  /// Lanza [ArgumentError] si [descripcion] está vacía o son solo
  /// espacios -- nunca genera una propuesta a partir de nada.
  Future<PropuestaPresupuesto> generar(String descripcion);
}
