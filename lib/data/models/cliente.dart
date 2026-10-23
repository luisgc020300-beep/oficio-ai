// lib/data/models/cliente.dart
class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.direccion,
    this.notas,
    required this.creadoEl,
    this.esDemo = false,
  });

  final String id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final DateTime creadoEl;

  /// true solo en los clientes precargados de ejemplo (ver demo_seed.dart)
  /// -- nunca en nada que el usuario cree. Sirve para avisar en la
  /// interfaz de qué es un dato real y qué es solo de muestra.
  final bool esDemo;

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? email,
    String? direccion,
    String? notas,
  }) => Cliente(
    id: id,
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    direccion: direccion ?? this.direccion,
    notas: notas ?? this.notas,
    creadoEl: creadoEl,
    esDemo: esDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'notas': notas,
    'creadoEl': creadoEl.toIso8601String(),
    'esDemo': esDemo,
  };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    direccion: json['direccion'] as String?,
    notas: json['notas'] as String?,
    creadoEl: DateTime.parse(json['creadoEl'] as String),
    // Dato guardado antes de que existiera este campo -> false por
    // defecto, nunca rompe la lectura de datos ya persistidos.
    esDemo: json['esDemo'] as bool? ?? false,
  );
}
