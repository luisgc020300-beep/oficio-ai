// lib/data/models/nota_seguimiento.dart
//
// Nota de seguimiento comercial de un cliente (iteración 11). No es un
// registro económico -- a diferencia de Factura/Gasto, se puede editar o
// borrar de verdad (NotaSeguimientoRepository.eliminar()), sin estado
// "anulado" ni rastro obligatorio: aquí no hay nada fiscal que proteger.
//
// El "seguimiento" (fecha para volver a contactar) vive en la propia
// nota en vez de como una entidad aparte -- una nota siempre lleva un
// texto, así que programar un seguimiento sin explicar el motivo no
// tendría sentido. [fechaSeguimiento] null significa que esta nota no
// programa ningún seguimiento (es solo una nota del historial).
enum TipoNota { general, llamada, visita, seguimientoPresupuesto, otro }

String nombreTipoNota(TipoNota t) => switch (t) {
  TipoNota.general => 'Nota general',
  TipoNota.llamada => 'Llamada',
  TipoNota.visita => 'Visita',
  TipoNota.seguimientoPresupuesto => 'Seguimiento de presupuesto',
  TipoNota.otro => 'Otro',
};

TipoNota tipoNotaFromString(String? s) =>
    TipoNota.values.firstWhere((t) => t.name == s, orElse: () => TipoNota.general);

/// Solo tiene sentido cuando la nota programa un seguimiento (ver
/// [NotaSeguimiento.fechaSeguimiento]) -- null en una nota sin
/// seguimiento. El paso del tiempo NUNCA cambia este valor por sí solo
/// (encargo, sección 3): una fecha pasada con estado [pendiente] es un
/// seguimiento "atrasado", no uno completado -- distinguir eso es cosa
/// de quien lo calcula (ver NotaSeguimiento.estaAtrasado), no del
/// estado guardado.
enum EstadoSeguimiento { pendiente, realizado, cancelado }

String nombreEstadoSeguimiento(EstadoSeguimiento e) => switch (e) {
  EstadoSeguimiento.pendiente => 'Pendiente',
  EstadoSeguimiento.realizado => 'Realizado',
  EstadoSeguimiento.cancelado => 'Cancelado',
};

EstadoSeguimiento estadoSeguimientoFromString(String? s) => EstadoSeguimiento.values
    .firstWhere((e) => e.name == s, orElse: () => EstadoSeguimiento.pendiente);

class NotaSeguimiento {
  const NotaSeguimiento({
    required this.id,
    required this.clienteId,
    required this.texto,
    this.tipo = TipoNota.general,
    required this.creadoEl,
    this.presupuestoId,
    this.trabajoId,
    this.fechaSeguimiento,
    this.estadoSeguimiento,
  });

  final String id;
  final String clienteId;
  final String texto;
  final TipoNota tipo;
  final DateTime creadoEl;

  /// Referencia opcional a un presupuesto o trabajo YA EXISTENTE -- no
  /// se valida aquí que exista (lo hace quien construye la nota, ver
  /// nota_seguimiento_form_sheet.dart), pero nunca se inventa la
  /// relación si el usuario no la ha indicado explícitamente.
  final String? presupuestoId;
  final String? trabajoId;

  /// Fecha para volver a contactar. Null si esta nota no programa
  /// ningún seguimiento.
  final DateTime? fechaSeguimiento;

  /// Null si [fechaSeguimiento] es null. Si hay fecha, nunca debe ser
  /// null -- NotaSeguimientoRepository.add()/actualizar() lo exigen
  /// (por defecto [EstadoSeguimiento.pendiente] al programarlo).
  final EstadoSeguimiento? estadoSeguimiento;

  bool get tieneSeguimiento => fechaSeguimiento != null;

  /// Solo un seguimiento [EstadoSeguimiento.pendiente] puede estar
  /// "atrasado" o "ser hoy" -- uno ya marcado realizado/cancelado no, por
  /// muy vieja que sea su fecha (encargo, sección 3: no reclasificar
  /// solo por el paso del tiempo). [ahora] es parametrizable para que
  /// los tests no dependan de la fecha real del sistema -- mismo
  /// criterio que Factura.estaVencida().
  bool esSeguimientoAtrasado({DateTime? ahora}) {
    if (fechaSeguimiento == null || estadoSeguimiento != EstadoSeguimiento.pendiente) {
      return false;
    }
    final hoy = ahora ?? DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return fechaSeguimiento!.isBefore(inicioHoy);
  }

  bool esSeguimientoHoy({DateTime? ahora}) {
    if (fechaSeguimiento == null || estadoSeguimiento != EstadoSeguimiento.pendiente) {
      return false;
    }
    final hoy = ahora ?? DateTime.now();
    final f = fechaSeguimiento!;
    return f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
  }

  /// Pendiente y con fecha futura (ni hoy ni atrasado).
  bool esSeguimientoFuturo({DateTime? ahora}) {
    if (fechaSeguimiento == null || estadoSeguimiento != EstadoSeguimiento.pendiente) {
      return false;
    }
    return !esSeguimientoAtrasado(ahora: ahora) && !esSeguimientoHoy(ahora: ahora);
  }

  NotaSeguimiento copyWith({
    String? texto,
    TipoNota? tipo,
    String? presupuestoId,
    String? trabajoId,
    DateTime? fechaSeguimiento,
    EstadoSeguimiento? estadoSeguimiento,
    bool borrarPresupuestoId = false,
    bool borrarTrabajoId = false,
    bool borrarSeguimiento = false,
  }) => NotaSeguimiento(
    id: id,
    clienteId: clienteId,
    texto: texto ?? this.texto,
    tipo: tipo ?? this.tipo,
    creadoEl: creadoEl,
    presupuestoId: borrarPresupuestoId ? null : (presupuestoId ?? this.presupuestoId),
    trabajoId: borrarTrabajoId ? null : (trabajoId ?? this.trabajoId),
    fechaSeguimiento: borrarSeguimiento ? null : (fechaSeguimiento ?? this.fechaSeguimiento),
    estadoSeguimiento: borrarSeguimiento
        ? null
        : (estadoSeguimiento ?? this.estadoSeguimiento),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'texto': texto,
    'tipo': tipo.name,
    'creadoEl': creadoEl.toIso8601String(),
    'presupuestoId': presupuestoId,
    'trabajoId': trabajoId,
    'fechaSeguimiento': fechaSeguimiento?.toIso8601String(),
    'estadoSeguimiento': estadoSeguimiento?.name,
  };

  factory NotaSeguimiento.fromJson(Map<String, dynamic> json) => NotaSeguimiento(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    texto: json['texto'] as String,
    tipo: tipoNotaFromString(json['tipo'] as String?),
    creadoEl: DateTime.parse(json['creadoEl'] as String),
    presupuestoId: json['presupuestoId'] as String?,
    trabajoId: json['trabajoId'] as String?,
    fechaSeguimiento: json['fechaSeguimiento'] != null
        ? DateTime.parse(json['fechaSeguimiento'] as String)
        : null,
    estadoSeguimiento: json['estadoSeguimiento'] != null
        ? estadoSeguimientoFromString(json['estadoSeguimiento'] as String?)
        : null,
  );
}
