// lib/data/models/factura.dart
//
// Modelo de factura. Diferencia deliberadamente dos cosas que la
// iteración 5 pide no confundir nunca (ver encargo, sección 2):
//
// - [estado] es la única fuente de verdad sobre el ciclo de vida fiscal
//   del documento (borrador -> emitida -> [anulada]) y SOLO cambia a
//   través de FacturaRepository.emitir()/anular() -- nunca se escribe a
//   mano desde una pantalla.
// - "pagada", "pagada parcial" y "vencida" NO son estados guardados: son
//   propiedades calculadas en cada lectura a partir de [pagos] (lista de
//   solo-anexado) y [fechaVencimiento]. Al depender únicamente de datos
//   ya persistidos (nunca de una bandera aparte que alguien pueda dejar
//   desincronizada), un simple refresco de la interfaz no puede hacer
//   que una factura pagada vuelva a verse como pendiente.
import 'concepto_presupuesto.dart';
import 'datos_negocio.dart';
import 'factura_totals.dart';
import 'pago_factura.dart';

enum EstadoFactura { borrador, emitida, anulada }

String nombreEstadoFactura(EstadoFactura e) => switch (e) {
  EstadoFactura.borrador => 'Borrador',
  EstadoFactura.emitida => 'Emitida',
  EstadoFactura.anulada => 'Anulada',
};

EstadoFactura estadoFacturaFromString(String? s) => EstadoFactura.values
    .firstWhere((e) => e.name == s, orElse: () => EstadoFactura.borrador);

class Factura {
  const Factura({
    required this.id,
    required this.clienteId,
    this.trabajoId,
    this.presupuestoId,
    required this.titulo,
    required this.conceptos,
    this.ivaPorcentaje = 21,
    this.descuentoPorcentaje = 0,
    this.estado = EstadoFactura.borrador,
    this.anio,
    this.numeroSecuencial,
    required this.creadaEl,
    this.fechaEmision,
    this.fechaVencimiento,
    this.motivoAnulacion,
    this.fechaAnulacion,
    this.pagos = const [],
    this.esDemo = false,
    this.datosEmisor,
  });

  final String id;
  final String clienteId;
  final String? trabajoId;
  final String? presupuestoId;
  final String titulo;
  final List<ConceptoPresupuesto> conceptos;
  final double ivaPorcentaje;
  final double descuentoPorcentaje;
  final EstadoFactura estado;

  /// Serie = año de emisión. Null mientras es borrador -- el número
  /// fiscal solo se asigna al emitir (ver FacturaRepository.emitir), así
  /// que un borrador descartado nunca deja un hueco en la numeración.
  final int? anio;

  /// Correlativo dentro de [anio]. Junto a [anio] forma [numero].
  final int? numeroSecuencial;

  final DateTime creadaEl;
  final DateTime? fechaEmision;
  final DateTime? fechaVencimiento;

  /// Motivo obligatorio al anular (ver FacturaRepository.anular) -- la
  /// factura y su número se conservan, nunca se borran ni se reutilizan.
  final String? motivoAnulacion;
  final DateTime? fechaAnulacion;

  /// Historial de cobros, de solo-anexado. Ver pago_factura.dart.
  final List<PagoFactura> pagos;

  /// true solo en las facturas precargadas de ejemplo -- ver nota en
  /// cliente.dart. Nunca se muestra como una factura real del usuario.
  final bool esDemo;

  /// Fotografía de los datos del negocio en el momento de EMITIR (no de
  /// crear el borrador) -- se fija una sola vez en
  /// FacturaRepository.emitir() y nunca vuelve a tocarse. Si después el
  /// usuario cambia su nombre, NIF o domicilio en "Mi negocio", esta
  /// factura sigue mostrando con quién se emitió de verdad. Null en
  /// facturas sin emitir y en las emitidas antes de que este campo
  /// existiera (compatibilidad hacia atrás).
  final DatosNegocio? datosEmisor;

  /// Referencia visible, p. ej. "2026-0003". Null mientras es borrador.
  String? get numero => (anio == null || numeroSecuencial == null)
      ? null
      : '$anio-${numeroSecuencial.toString().padLeft(4, '0')}';

  FacturaTotals get totales =>
      calcularTotalesFactura(conceptos, ivaPorcentaje, descuentoPorcentaje);

  double get totalCobrado =>
      redondear2(pagos.fold<double>(0, (acc, p) => acc + p.importe));

  double get saldoPendiente {
    final saldo = redondear2(totales.total - totalCobrado);
    return saldo < 0 ? 0 : saldo;
  }

  /// Completamente cobrada. Solo tiene sentido sobre una factura emitida
  /// -- un borrador o una anulada nunca se consideran "pagadas".
  bool get pagadaCompleta =>
      estado == EstadoFactura.emitida && saldoPendiente <= 0;

  bool get pagadaParcial =>
      estado == EstadoFactura.emitida && totalCobrado > 0 && !pagadaCompleta;

  /// [ahora] es parametrizable para que los tests no dependan de la
  /// fecha real del sistema.
  bool estaVencida({DateTime? ahora}) {
    if (estado != EstadoFactura.emitida || pagadaCompleta) return false;
    if (fechaVencimiento == null) return false;
    return (ahora ?? DateTime.now()).isAfter(fechaVencimiento!);
  }

  Factura copyWith({
    String? clienteId,
    String? trabajoId,
    String? presupuestoId,
    String? titulo,
    List<ConceptoPresupuesto>? conceptos,
    double? ivaPorcentaje,
    double? descuentoPorcentaje,
    EstadoFactura? estado,
    int? anio,
    int? numeroSecuencial,
    DateTime? fechaEmision,
    DateTime? fechaVencimiento,
    String? motivoAnulacion,
    DateTime? fechaAnulacion,
    List<PagoFactura>? pagos,
    DatosNegocio? datosEmisor,
  }) => Factura(
    id: id,
    clienteId: clienteId ?? this.clienteId,
    trabajoId: trabajoId ?? this.trabajoId,
    presupuestoId: presupuestoId ?? this.presupuestoId,
    titulo: titulo ?? this.titulo,
    conceptos: conceptos ?? this.conceptos,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
    estado: estado ?? this.estado,
    anio: anio ?? this.anio,
    numeroSecuencial: numeroSecuencial ?? this.numeroSecuencial,
    creadaEl: creadaEl,
    fechaEmision: fechaEmision ?? this.fechaEmision,
    fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
    motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
    fechaAnulacion: fechaAnulacion ?? this.fechaAnulacion,
    pagos: pagos ?? this.pagos,
    esDemo: esDemo,
    datosEmisor: datosEmisor ?? this.datosEmisor,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'trabajoId': trabajoId,
    'presupuestoId': presupuestoId,
    'titulo': titulo,
    'conceptos': conceptos.map((c) => c.toJson()).toList(),
    'ivaPorcentaje': ivaPorcentaje,
    'descuentoPorcentaje': descuentoPorcentaje,
    'estado': estado.name,
    'anio': anio,
    'numeroSecuencial': numeroSecuencial,
    'creadaEl': creadaEl.toIso8601String(),
    'fechaEmision': fechaEmision?.toIso8601String(),
    'fechaVencimiento': fechaVencimiento?.toIso8601String(),
    'motivoAnulacion': motivoAnulacion,
    'fechaAnulacion': fechaAnulacion?.toIso8601String(),
    'pagos': pagos.map((p) => p.toJson()).toList(),
    'esDemo': esDemo,
    'datosEmisor': datosEmisor?.toJson(),
  };

  factory Factura.fromJson(Map<String, dynamic> json) => Factura(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    trabajoId: json['trabajoId'] as String?,
    presupuestoId: json['presupuestoId'] as String?,
    titulo: json['titulo'] as String,
    conceptos: (json['conceptos'] as List)
        .map((c) => ConceptoPresupuesto.fromJson(c as Map<String, dynamic>))
        .toList(),
    ivaPorcentaje: (json['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
    descuentoPorcentaje: (json['descuentoPorcentaje'] as num?)?.toDouble() ?? 0,
    estado: estadoFacturaFromString(json['estado'] as String?),
    anio: json['anio'] as int?,
    numeroSecuencial: json['numeroSecuencial'] as int?,
    creadaEl: DateTime.parse(json['creadaEl'] as String),
    fechaEmision: json['fechaEmision'] != null
        ? DateTime.parse(json['fechaEmision'] as String)
        : null,
    fechaVencimiento: json['fechaVencimiento'] != null
        ? DateTime.parse(json['fechaVencimiento'] as String)
        : null,
    motivoAnulacion: json['motivoAnulacion'] as String?,
    fechaAnulacion: json['fechaAnulacion'] != null
        ? DateTime.parse(json['fechaAnulacion'] as String)
        : null,
    pagos: json['pagos'] == null
        ? const []
        : (json['pagos'] as List)
              .map((p) => PagoFactura.fromJson(p as Map<String, dynamic>))
              .toList(),
    esDemo: json['esDemo'] as bool? ?? false,
    datosEmisor: json['datosEmisor'] != null
        ? DatosNegocio.fromJson(json['datosEmisor'] as Map<String, dynamic>)
        : null,
  );
}
