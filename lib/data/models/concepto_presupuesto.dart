// lib/data/models/concepto_presupuesto.dart
class ConceptoPresupuesto {
  const ConceptoPresupuesto({
    required this.id,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  final String id;
  final String descripcion;
  final double cantidad;
  final double precioUnitario;

  double get subtotal => cantidad * precioUnitario;

  ConceptoPresupuesto copyWith({
    String? descripcion,
    double? cantidad,
    double? precioUnitario,
  }) => ConceptoPresupuesto(
    id: id,
    descripcion: descripcion ?? this.descripcion,
    cantidad: cantidad ?? this.cantidad,
    precioUnitario: precioUnitario ?? this.precioUnitario,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'descripcion': descripcion,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
  };

  factory ConceptoPresupuesto.fromJson(Map<String, dynamic> json) =>
      ConceptoPresupuesto(
        id: json['id'] as String,
        descripcion: json['descripcion'] as String,
        cantidad: (json['cantidad'] as num).toDouble(),
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
      );
}
