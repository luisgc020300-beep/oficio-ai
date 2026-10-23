// lib/data/models/pago_factura.dart
//
// Un cobro registrado contra una factura. Vive embebido en Factura.pagos
// (igual que ConceptoPresupuesto vive embebido en Presupuesto.conceptos)
// -- no es un repositorio aparte porque un pago no tiene sentido sin la
// factura a la que pertenece, y así se guarda/carga siempre en el mismo
// ciclo que la factura, sin tener que sincronizar dos colecciones.
//
// La lista de pagos es de solo-anexado desde la UI (FacturaRepository no
// expone editar ni borrar un pago ya registrado -- ver nota en
// factura_repository.dart) para conservar la trazabilidad de los cobros.
enum MetodoPago { efectivo, transferencia, tarjeta, bizum, otro }

String nombreMetodoPago(MetodoPago m) => switch (m) {
  MetodoPago.efectivo => 'Efectivo',
  MetodoPago.transferencia => 'Transferencia',
  MetodoPago.tarjeta => 'Tarjeta',
  MetodoPago.bizum => 'Bizum',
  MetodoPago.otro => 'Otro',
};

MetodoPago metodoPagoFromString(String? s) =>
    MetodoPago.values.firstWhere((m) => m.name == s, orElse: () => MetodoPago.otro);

class PagoFactura {
  const PagoFactura({
    required this.id,
    required this.fecha,
    required this.importe,
    this.metodo = MetodoPago.otro,
    this.nota,
    required this.registradoEl,
  });

  final String id;

  /// Fecha efectiva en la que se recibió el cobro -- es la que se usa
  /// para agrupar cobros por periodo en el dashboard (sección 8 del
  /// encargo: "los cobros se agrupan por fecha efectiva del pago"), y
  /// puede ser distinta de [registradoEl] si se anota con retraso.
  final DateTime fecha;
  final double importe;
  final MetodoPago metodo;
  final String? nota;

  /// Cuándo se guardó este registro en la app -- solo para trazabilidad
  /// interna, nunca se usa para agrupar ni calcular periodos.
  final DateTime registradoEl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fecha': fecha.toIso8601String(),
    'importe': importe,
    'metodo': metodo.name,
    'nota': nota,
    'registradoEl': registradoEl.toIso8601String(),
  };

  factory PagoFactura.fromJson(Map<String, dynamic> json) => PagoFactura(
    id: json['id'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    importe: (json['importe'] as num).toDouble(),
    metodo: metodoPagoFromString(json['metodo'] as String?),
    nota: json['nota'] as String?,
    registradoEl: json['registradoEl'] != null
        ? DateTime.parse(json['registradoEl'] as String)
        : DateTime.parse(json['fecha'] as String),
  );
}
