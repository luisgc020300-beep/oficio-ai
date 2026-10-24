// lib/data/models/gasto.dart
//
// Gasto del negocio (iteración 9) -- deliberadamente simple: ni centros
// de coste, ni impuestos, ni conciliación bancaria. Solo lo que un
// autónomo necesita para saber qué se ha gastado y, cuando aplica, en
// qué trabajo. Mismo patrón que Factura para no perder el historial al
// "borrar" uno: [estado] + [motivoAnulacion] + [fechaAnulacion], nunca
// un delete() silencioso (ver GastoRepository).
enum CategoriaGasto {
  materiales,
  desplazamiento,
  herramientas,
  subcontratacion,
  suministros,
  otros,
}

String nombreCategoriaGasto(CategoriaGasto c) => switch (c) {
  CategoriaGasto.materiales => 'Materiales',
  CategoriaGasto.desplazamiento => 'Desplazamiento',
  CategoriaGasto.herramientas => 'Herramientas',
  CategoriaGasto.subcontratacion => 'Subcontratación',
  CategoriaGasto.suministros => 'Suministros',
  CategoriaGasto.otros => 'Otros',
};

CategoriaGasto categoriaGastoFromString(String? s) => CategoriaGasto.values
    .firstWhere((c) => c.name == s, orElse: () => CategoriaGasto.otros);

enum EstadoGasto { activo, anulado }

String nombreEstadoGasto(EstadoGasto e) => switch (e) {
  EstadoGasto.activo => 'Activo',
  EstadoGasto.anulado => 'Anulado',
};

EstadoGasto estadoGastoFromString(String? s) => EstadoGasto.values
    .firstWhere((e) => e.name == s, orElse: () => EstadoGasto.activo);

class Gasto {
  const Gasto({
    required this.id,
    required this.descripcion,
    required this.importe,
    required this.fecha,
    this.categoria = CategoriaGasto.otros,
    this.proveedor,
    this.notas,
    this.trabajoId,
    required this.creadoEl,
    this.estado = EstadoGasto.activo,
    this.motivoAnulacion,
    this.fechaAnulacion,
    this.esDemo = false,
  });

  final String id;
  final String descripcion;

  /// Siempre > 0 -- GastoRepository.add()/update() lo exigen. Un gasto
  /// nunca se representa en negativo (a diferencia de una rectificativa
  /// de factura, que sí puede serlo): para corregir un gasto registrado
  /// de más, se anula y, si procede, se crea uno nuevo correcto -- igual
  /// que con una factura.
  final double importe;

  /// Fecha en la que se produjo el gasto (no en la que se registró en
  /// la app) -- es la que se usa para agrupar por periodo (ver
  /// dashboard_screen.dart y job_detail_screen.dart), igual que
  /// Factura.fechaEmision para la facturación.
  final DateTime fecha;

  final CategoriaGasto categoria;
  final String? proveedor;
  final String? notas;

  /// Trabajo al que se atribuye este gasto -- null si es un gasto
  /// general del negocio, no de un trabajo concreto. Nunca se infiere
  /// ni se asigna automáticamente (encargo, sección 4): si el usuario
  /// no lo indica, se queda sin trabajo, y así se mantiene en los
  /// totales generales sin aparecer en la rentabilidad de ninguno.
  final String? trabajoId;

  final DateTime creadoEl;

  /// [EstadoGasto.anulado] preserva el gasto (importe, fecha, trabajo...)
  /// tal cual se registró -- nunca se borra ni se edita un gasto
  /// anulado. Un gasto anulado NUNCA debe sumarse en ningún total activo
  /// (ver GastoRepository.activos y los cálculos de rentabilidad/
  /// resumen mensual).
  final EstadoGasto estado;
  final String? motivoAnulacion;
  final DateTime? fechaAnulacion;

  /// true solo en gastos de ejemplo -- ver nota en cliente.dart. Esta
  /// iteración no siembra ningún gasto de ejemplo (ver demo_seed.dart),
  /// pero el campo existe desde el principio por si se añaden más
  /// adelante, para no tener que migrar datos ya guardados.
  final bool esDemo;

  bool get estaAnulado => estado == EstadoGasto.anulado;

  Gasto copyWith({
    String? descripcion,
    double? importe,
    DateTime? fecha,
    CategoriaGasto? categoria,
    String? proveedor,
    String? notas,
    String? trabajoId,
    EstadoGasto? estado,
    String? motivoAnulacion,
    DateTime? fechaAnulacion,
  }) => Gasto(
    id: id,
    descripcion: descripcion ?? this.descripcion,
    importe: importe ?? this.importe,
    fecha: fecha ?? this.fecha,
    categoria: categoria ?? this.categoria,
    proveedor: proveedor ?? this.proveedor,
    notas: notas ?? this.notas,
    trabajoId: trabajoId ?? this.trabajoId,
    creadoEl: creadoEl,
    estado: estado ?? this.estado,
    motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
    fechaAnulacion: fechaAnulacion ?? this.fechaAnulacion,
    esDemo: esDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'descripcion': descripcion,
    'importe': importe,
    'fecha': fecha.toIso8601String(),
    'categoria': categoria.name,
    'proveedor': proveedor,
    'notas': notas,
    'trabajoId': trabajoId,
    'creadoEl': creadoEl.toIso8601String(),
    'estado': estado.name,
    'motivoAnulacion': motivoAnulacion,
    'fechaAnulacion': fechaAnulacion?.toIso8601String(),
    'esDemo': esDemo,
  };

  factory Gasto.fromJson(Map<String, dynamic> json) => Gasto(
    id: json['id'] as String,
    descripcion: json['descripcion'] as String,
    importe: (json['importe'] as num).toDouble(),
    fecha: DateTime.parse(json['fecha'] as String),
    categoria: categoriaGastoFromString(json['categoria'] as String?),
    proveedor: json['proveedor'] as String?,
    notas: json['notas'] as String?,
    trabajoId: json['trabajoId'] as String?,
    creadoEl: json['creadoEl'] != null
        ? DateTime.parse(json['creadoEl'] as String)
        : DateTime.parse(json['fecha'] as String),
    estado: estadoGastoFromString(json['estado'] as String?),
    motivoAnulacion: json['motivoAnulacion'] as String?,
    fechaAnulacion: json['fechaAnulacion'] != null
        ? DateTime.parse(json['fechaAnulacion'] as String)
        : null,
    esDemo: json['esDemo'] as bool? ?? false,
  );
}
