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
import 'cliente_snapshot.dart';
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

/// Factura ordinaria frente a rectificativa (iteración 8, art. 15 RD
/// 1619/2012). Una rectificativa es un documento independiente: nunca
/// sustituye ni edita la original (ver FacturaRepository.anular() y la
/// nota en [facturaOriginalId]).
enum TipoDocumentoFactura { ordinaria, rectificativa }

TipoDocumentoFactura tipoDocumentoFacturaFromString(String? s) =>
    TipoDocumentoFactura.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoDocumentoFactura.ordinaria,
    );

/// Las dos modalidades que permite el art. 15.5 del RD 1619/2012 para
/// expresar una rectificación -- el emisor puede elegir libremente
/// entre ellas, la norma no impone una:
///
/// - [porDiferencias]: la rectificativa consigna solo el IMPORTE DE LA
///   DIFERENCIA (con su signo), no el total de la operación. Sus
///   [Factura.conceptos] representan esa diferencia -- un
///   `precioUnitario` negativo es lo esperado cuando la corrección
///   reduce lo facturado, no un error de los datos.
/// - [importeResultante]: la rectificativa consigna los importes TAL Y
///   COMO QUEDAN tras la corrección (sustituyendo lo antes declarado),
///   y además debe señalar igualmente el importe de la rectificación
///   -- ver [Factura.importeRectificacion].
enum ModalidadRectificacion { porDiferencias, importeResultante }

ModalidadRectificacion? modalidadRectificacionFromString(String? s) {
  if (s == null) return null;
  return ModalidadRectificacion.values.firstWhere(
    (m) => m.name == s,
    orElse: () => ModalidadRectificacion.porDiferencias,
  );
}

/// Serie obligatoria para toda rectificativa (art. 6.1.a RD 1619/2012:
/// "será obligatoria, en todo caso, la expedición en series específicas
/// ... [de] las rectificativas"). Las facturas ordinarias no necesitan
/// serie -- separar por series solo es obligatorio para los supuestos
/// que la norma lista expresamente, y las rectificativas son uno de
/// ellos.
const serieRectificativas = 'R';

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
    this.datosCliente,
    this.tipoDocumento = TipoDocumentoFactura.ordinaria,
    this.serie = '',
    this.facturaOriginalId,
    this.motivoRectificacion,
    this.modalidadRectificacion,
    this.importeRectificacion,
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

  /// Año de emisión. Null mientras es borrador -- el número fiscal solo
  /// se asigna al emitir (ver FacturaRepository.emitir), así que un
  /// borrador descartado nunca deja un hueco en la numeración.
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

  /// Fotografía de los datos del cliente en el momento de EMITIR --
  /// mismo principio y mismas garantías que [datosEmisor] (iteración
  /// 7.1), pero para el cliente en vez del negocio: a diferencia de
  /// [clienteId] (que sigue apuntando al registro real, para conservar
  /// la navegación y la relación), esto no cambia si el cliente edita
  /// después su nombre o domicilio. Null en borradores y en facturas
  /// emitidas antes de que este campo existiera.
  final ClienteSnapshot? datosCliente;

  /// Ordinaria por defecto -- toda factura anterior a la iteración 8 se
  /// lee como ordinaria (compatibilidad hacia atrás, ver fromJson).
  final TipoDocumentoFactura tipoDocumento;

  /// '' (serie implícita, formato "AAAA-NNNN") para facturas ordinarias
  /// -- ninguna factura emitida antes de esta iteración tenía serie, así
  /// que mantener '' como valor por defecto no les cambia el número.
  /// Las rectificativas usan [serieRectificativas] ('R'), obligatorio
  /// según el art. 6.1.a RD 1619/2012 -- ver FacturaRepository.emitir()
  /// para la numeración correlativa dentro de cada combinación
  /// (serie, año).
  final String serie;

  /// Id de la factura que esta rectificativa corrige -- una referencia
  /// estable al registro, no una copia de sus datos (al revés que
  /// [datosEmisor]/[datosCliente]): la original nunca se borra una vez
  /// emitida (ver FacturaRepository.delete()/anular()), así que esta
  /// relación no se puede romper por nada que el repositorio permita
  /// hacer, ni siquiera si la original se anula o el cliente cambia sus
  /// datos después. Null en facturas ordinarias.
  final String? facturaOriginalId;

  /// Motivo de la rectificación, obligatorio para emitir una
  /// rectificativa (ver FacturaRepository.emitir()) -- null en
  /// facturas ordinarias y en borradores de rectificativa todavía sin
  /// rellenar.
  final String? motivoRectificacion;

  /// Qué modalidad del art. 15.5 RD 1619/2012 usa esta rectificativa.
  /// Null en facturas ordinarias.
  final ModalidadRectificacion? modalidadRectificacion;

  /// Solo tiene valor cuando [modalidadRectificacion] es
  /// [ModalidadRectificacion.importeResultante]: el importe NETO de la
  /// corrección (con signo), calculado una sola vez al crear la
  /// rectificativa como `totalCorregido - totalOriginal` (ver
  /// FacturaRepository.add()) y guardado tal cual -- nunca recalculado
  /// a partir de [totales], porque en esa modalidad [totales] expresa
  /// el importe YA CORREGIDO, no la diferencia. Es el campo que evita
  /// la doble contabilización en los indicadores del dashboard (ver
  /// [importeFacturacion]) cuando la rectificativa declara el importe
  /// completo en vez de solo la diferencia. Null en facturas ordinarias
  /// y en rectificativas [ModalidadRectificacion.porDiferencias] (ahí
  /// [totales] ya ES la diferencia, no hace falta guardarla aparte).
  final double? importeRectificacion;

  /// Referencia visible. "2026-0003" para una factura ordinaria,
  /// "R-2026-0003" para una rectificativa (serie obligatoria, ver
  /// [serie]). Null mientras es borrador.
  String? get numero {
    if (anio == null || numeroSecuencial == null) return null;
    final base = '$anio-${numeroSecuencial.toString().padLeft(4, '0')}';
    return serie.isEmpty ? base : '$serie-$base';
  }

  FacturaTotals get totales =>
      calcularTotalesFactura(conceptos, ivaPorcentaje, descuentoPorcentaje);

  /// Lo que este documento aporta a un indicador agregado de
  /// facturación (dashboard, listados) -- NO lo que hay que mostrar en
  /// el propio documento, para eso está [totales.total] tal cual.
  ///
  /// - Factura ordinaria o rectificativa [porDiferencias]: coincide con
  ///   [totales.total] -- en esta última modalidad, [totales] YA es la
  ///   diferencia, sumarla junto a la original da el neto correcto.
  /// - Rectificativa [importeResultante]: [totales.total] es el importe
  ///   COMPLETO ya corregido, no una diferencia -- sumarlo junto a la
  ///   original (que sigue aportando su importe original sin cambios)
  ///   contaría la operación dos veces. Se usa en su lugar
  ///   [importeRectificacion], la diferencia neta ya calculada al
  ///   crear la rectificativa (ver FacturaRepository.add()).
  double get importeFacturacion {
    if (tipoDocumento != TipoDocumentoFactura.rectificativa) {
      return totales.total;
    }
    return importeRectificacion ?? totales.total;
  }

  double get totalCobrado =>
      redondear2(pagos.fold<double>(0, (acc, p) => acc + p.importe));

  /// Una rectificativa nunca registra cobros propios -- ver
  /// FacturaRepository.registrarPago(), que lo rechaza explícitamente
  /// -- así que su saldo pendiente siempre es 0, se declare el importe
  /// completo corregido o solo la diferencia. Sin esto, una
  /// rectificativa [ModalidadRectificacion.importeResultante] (que
  /// declara el importe COMPLETO, no solo la diferencia) aparecería
  /// como una factura aparte con saldo pendiente real, duplicando lo
  /// que la original ya tiene pendiente (o cobrado) por su cuenta.
  double get saldoPendiente {
    if (tipoDocumento == TipoDocumentoFactura.rectificativa) return 0;
    final saldo = redondear2(totales.total - totalCobrado);
    return saldo < 0 ? 0 : saldo;
  }

  /// Completamente cobrada. Solo tiene sentido sobre una factura emitida
  /// -- un borrador o una anulada nunca se consideran "pagadas". Una
  /// rectificativa emitida siempre cumple esto trivialmente (ver
  /// [saldoPendiente]) -- la interfaz no debe mostrarla con la misma
  /// etiqueta "Pagada" que una factura ordinaria cobrada de verdad (ver
  /// invoice_detail_screen.dart/invoices_list_screen.dart).
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
    ClienteSnapshot? datosCliente,
    String? serie,
    double? importeRectificacion,
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
    datosCliente: datosCliente ?? this.datosCliente,
    // Siempre se preservan tal cual -- ver nota en cada campo: ninguno
    // de estos cambia después de crear la factura, salvo
    // [importeRectificacion] (FacturaRepository.add() lo recalcula una
    // sola vez al crear la rectificativa).
    tipoDocumento: tipoDocumento,
    serie: serie ?? this.serie,
    facturaOriginalId: facturaOriginalId,
    motivoRectificacion: motivoRectificacion,
    modalidadRectificacion: modalidadRectificacion,
    importeRectificacion: importeRectificacion ?? this.importeRectificacion,
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
    'datosCliente': datosCliente?.toJson(),
    'tipoDocumento': tipoDocumento.name,
    'serie': serie,
    'facturaOriginalId': facturaOriginalId,
    'motivoRectificacion': motivoRectificacion,
    'modalidadRectificacion': modalidadRectificacion?.name,
    'importeRectificacion': importeRectificacion,
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
    datosCliente: json['datosCliente'] != null
        ? ClienteSnapshot.fromJson(json['datosCliente'] as Map<String, dynamic>)
        : null,
    // Ausentes en cualquier JSON guardado antes de la iteración 8 --
    // se leen como una factura ordinaria sin relación de rectificación
    // alguna, nunca se infiere ni se rellena nada.
    tipoDocumento: tipoDocumentoFacturaFromString(json['tipoDocumento'] as String?),
    serie: json['serie'] as String? ?? '',
    facturaOriginalId: json['facturaOriginalId'] as String?,
    motivoRectificacion: json['motivoRectificacion'] as String?,
    modalidadRectificacion: modalidadRectificacionFromString(
      json['modalidadRectificacion'] as String?,
    ),
    importeRectificacion: (json['importeRectificacion'] as num?)?.toDouble(),
  );
}
