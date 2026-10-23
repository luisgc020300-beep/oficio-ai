// lib/data/models/presupuesto.dart
import 'concepto_presupuesto.dart';
import 'quote_totals.dart';

enum EstadoPresupuesto { borrador, enviado, aceptado, rechazado }

String nombreEstadoPresupuesto(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => 'Borrador',
  EstadoPresupuesto.enviado => 'Enviado',
  EstadoPresupuesto.aceptado => 'Aceptado',
  EstadoPresupuesto.rechazado => 'Rechazado',
};

EstadoPresupuesto estadoPresupuestoFromString(String? s) =>
    EstadoPresupuesto.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoPresupuesto.borrador,
    );

class Presupuesto {
  const Presupuesto({
    required this.id,
    required this.clienteId,
    required this.titulo,
    required this.conceptos,
    this.ivaPorcentaje = 21,
    required this.estado,
    required this.creadoEl,
    this.trabajoId,
    this.esDemo = false,
  });

  final String id;
  final String clienteId;
  final String titulo;
  final List<ConceptoPresupuesto> conceptos;
  final double ivaPorcentaje;
  final EstadoPresupuesto estado;
  final DateTime creadoEl;
  final String? trabajoId;

  /// true solo en los presupuestos precargados de ejemplo -- ver nota en
  /// cliente.dart.
  final bool esDemo;

  QuoteTotals get totales => calcularTotales(conceptos, ivaPorcentaje);

  Presupuesto copyWith({
    String? titulo,
    List<ConceptoPresupuesto>? conceptos,
    double? ivaPorcentaje,
    EstadoPresupuesto? estado,
    String? trabajoId,
  }) => Presupuesto(
    id: id,
    clienteId: clienteId,
    titulo: titulo ?? this.titulo,
    conceptos: conceptos ?? this.conceptos,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    estado: estado ?? this.estado,
    creadoEl: creadoEl,
    trabajoId: trabajoId ?? this.trabajoId,
    esDemo: esDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'titulo': titulo,
    'conceptos': conceptos.map((c) => c.toJson()).toList(),
    'ivaPorcentaje': ivaPorcentaje,
    'estado': estado.name,
    'creadoEl': creadoEl.toIso8601String(),
    'trabajoId': trabajoId,
    'esDemo': esDemo,
  };

  factory Presupuesto.fromJson(Map<String, dynamic> json) => Presupuesto(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    titulo: json['titulo'] as String,
    conceptos: (json['conceptos'] as List)
        .map((c) => ConceptoPresupuesto.fromJson(c as Map<String, dynamic>))
        .toList(),
    ivaPorcentaje: (json['ivaPorcentaje'] as num).toDouble(),
    estado: estadoPresupuestoFromString(json['estado'] as String?),
    creadoEl: DateTime.parse(json['creadoEl'] as String),
    trabajoId: json['trabajoId'] as String?,
    esDemo: json['esDemo'] as bool? ?? false,
  );
}
