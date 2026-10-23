// lib/data/models/trabajo.dart
enum EstadoTrabajo { pendiente, enCurso, finalizado, cancelado }

String nombreEstadoTrabajo(EstadoTrabajo e) => switch (e) {
  EstadoTrabajo.pendiente => 'Pendiente',
  EstadoTrabajo.enCurso => 'En curso',
  EstadoTrabajo.finalizado => 'Finalizado',
  EstadoTrabajo.cancelado => 'Cancelado',
};

EstadoTrabajo estadoTrabajoFromString(String? s) => EstadoTrabajo.values
    .firstWhere((e) => e.name == s, orElse: () => EstadoTrabajo.pendiente);

class Trabajo {
  const Trabajo({
    required this.id,
    required this.clienteId,
    required this.titulo,
    this.descripcion,
    this.direccion,
    required this.estado,
    required this.creadoEl,
    this.fechaProgramada,
    this.presupuestoId,
    this.esDemo = false,
  });

  final String id;
  final String clienteId;
  final String titulo;
  final String? descripcion;
  final String? direccion;
  final EstadoTrabajo estado;
  final DateTime creadoEl;
  final DateTime? fechaProgramada;
  final String? presupuestoId;

  /// true solo en los trabajos precargados de ejemplo -- ver nota en
  /// cliente.dart.
  final bool esDemo;

  Trabajo copyWith({
    String? titulo,
    String? descripcion,
    String? direccion,
    EstadoTrabajo? estado,
    DateTime? fechaProgramada,
    String? presupuestoId,
  }) => Trabajo(
    id: id,
    clienteId: clienteId,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    direccion: direccion ?? this.direccion,
    estado: estado ?? this.estado,
    creadoEl: creadoEl,
    fechaProgramada: fechaProgramada ?? this.fechaProgramada,
    presupuestoId: presupuestoId ?? this.presupuestoId,
    esDemo: esDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'titulo': titulo,
    'descripcion': descripcion,
    'direccion': direccion,
    'estado': estado.name,
    'creadoEl': creadoEl.toIso8601String(),
    'fechaProgramada': fechaProgramada?.toIso8601String(),
    'presupuestoId': presupuestoId,
    'esDemo': esDemo,
  };

  factory Trabajo.fromJson(Map<String, dynamic> json) => Trabajo(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    titulo: json['titulo'] as String,
    descripcion: json['descripcion'] as String?,
    direccion: json['direccion'] as String?,
    estado: estadoTrabajoFromString(json['estado'] as String?),
    creadoEl: DateTime.parse(json['creadoEl'] as String),
    fechaProgramada: json['fechaProgramada'] != null
        ? DateTime.parse(json['fechaProgramada'] as String)
        : null,
    presupuestoId: json['presupuestoId'] as String?,
    esDemo: json['esDemo'] as bool? ?? false,
  );
}
