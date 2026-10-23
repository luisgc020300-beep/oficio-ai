// lib/data/models/cita.dart
class Cita {
  const Cita({
    required this.id,
    required this.titulo,
    required this.fechaHora,
    this.duracionMinutos = 60,
    this.clienteId,
    this.trabajoId,
    this.notas,
    this.completada = false,
    this.esDemo = false,
  });

  final String id;
  final String titulo;
  final DateTime fechaHora;
  final int duracionMinutos;
  final String? clienteId;
  final String? trabajoId;
  final String? notas;
  final bool completada;

  /// true solo en las citas precargadas de ejemplo -- ver nota en
  /// cliente.dart.
  final bool esDemo;

  DateTime get fin => fechaHora.add(Duration(minutes: duracionMinutos));

  Cita copyWith({
    String? titulo,
    DateTime? fechaHora,
    int? duracionMinutos,
    String? clienteId,
    String? trabajoId,
    String? notas,
    bool? completada,
  }) => Cita(
    id: id,
    titulo: titulo ?? this.titulo,
    fechaHora: fechaHora ?? this.fechaHora,
    duracionMinutos: duracionMinutos ?? this.duracionMinutos,
    clienteId: clienteId ?? this.clienteId,
    trabajoId: trabajoId ?? this.trabajoId,
    notas: notas ?? this.notas,
    completada: completada ?? this.completada,
    esDemo: esDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'fechaHora': fechaHora.toIso8601String(),
    'duracionMinutos': duracionMinutos,
    'clienteId': clienteId,
    'trabajoId': trabajoId,
    'notas': notas,
    'completada': completada,
    'esDemo': esDemo,
  };

  factory Cita.fromJson(Map<String, dynamic> json) => Cita(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    fechaHora: DateTime.parse(json['fechaHora'] as String),
    duracionMinutos: json['duracionMinutos'] as int? ?? 60,
    clienteId: json['clienteId'] as String?,
    trabajoId: json['trabajoId'] as String?,
    notas: json['notas'] as String?,
    completada: json['completada'] as bool? ?? false,
    esDemo: json['esDemo'] as bool? ?? false,
  );
}
