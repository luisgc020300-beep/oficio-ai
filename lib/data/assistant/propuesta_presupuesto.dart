// lib/data/assistant/propuesta_presupuesto.dart
//
// Resultado tipado de un generador de propuestas de presupuesto -- nunca
// un texto libre. `conceptos` usa el mismo modelo ConceptoPresupuesto que
// ya usa quote_form_screen.dart, así que una propuesta se puede volcar
// directamente en el formulario de revisión existente sin traducir nada.
import '../models/concepto_presupuesto.dart';

/// Qué tan segura está la generación de haber entendido el trabajo --
/// pensado para que un futuro proveedor de IA real pueda usar también
/// el nivel intermedio; el generador local de hoy solo usa alta/baja.
enum NivelConfianza { alta, media, baja }

class PropuestaPresupuesto {
  const PropuestaPresupuesto({
    required this.tituloSugerido,
    required this.conceptos,
    required this.confianza,
    required this.mensaje,
  });

  final String tituloSugerido;
  final List<ConceptoPresupuesto> conceptos;
  final NivelConfianza confianza;

  /// Explicación breve para el usuario -- qué ha reconocido el motor, o
  /// por qué la propuesta es genérica. Siempre visible en la pantalla de
  /// revisión, nunca oculta.
  final String mensaje;
}
