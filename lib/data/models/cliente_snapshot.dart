// lib/data/models/cliente_snapshot.dart
//
// Fotografía de los datos identificativos y de contacto de un cliente
// en el momento de EMITIR una factura -- mismo principio que
// DatosNegocio dentro de Factura.datosEmisor (ver factura.dart), pero
// para el cliente en vez del emisor.
//
// Deliberadamente NO es una copia completa de Cliente: no incluye
// `notas` (son apuntes privados del profesional sobre ese cliente, no
// un dato pensado para aparecer en un documento que se entrega fuera
// de la app) ni `esDemo`/`creadoEl` (metadatos administrativos del
// registro, no datos de la factura). Tampoco incluye un NIF del
// cliente porque el modelo Cliente no guarda ninguno -- nunca se
// inventa uno.
import 'cliente.dart';

class ClienteSnapshot {
  const ClienteSnapshot({
    required this.nombre,
    this.telefono,
    this.email,
    this.direccion,
  });

  factory ClienteSnapshot.desde(Cliente c) => ClienteSnapshot(
    nombre: c.nombre,
    telefono: c.telefono,
    email: c.email,
    direccion: c.direccion,
  );

  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
  };

  factory ClienteSnapshot.fromJson(Map<String, dynamic> json) => ClienteSnapshot(
    nombre: json['nombre'] as String? ?? '',
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    direccion: json['direccion'] as String?,
  );
}
