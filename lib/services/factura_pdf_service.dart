// lib/services/factura_pdf_service.dart
//
// Generación del PDF de una factura -- Dart puro, sin pantalla ni
// plugin nativo (la composición del documento con el paquete `pdf` no
// toca ninguna plataforma, así que se puede probar con `flutter test`
// normal y corriente). La vista previa/impresión/compartir viven en
// invoice_pdf_preview_screen.dart; este archivo solo construye los
// bytes del documento a partir de los datos ya calculados por el
// modelo -- no recalcula IVA, descuentos ni totales, los reutiliza tal
// cual vienen de Factura.totales/totalCobrado/saldoPendiente.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/formatters.dart';
import '../data/models/cliente.dart';
import '../data/models/cliente_snapshot.dart';
import '../data/models/concepto_presupuesto.dart';
import '../data/models/datos_negocio.dart';
import '../data/models/factura.dart';
import '../data/models/factura_totals.dart';
import '../data/models/pago_factura.dart';

const _pdfPrimary = PdfColor.fromInt(0xFF1E3A5F);
const _pdfAccentStrong = PdfColor.fromInt(0xFFC77418);
const _pdfInk = PdfColor.fromInt(0xFF16233B);
const _pdfInkMuted = PdfColor.fromInt(0xFF5B6475);
const _pdfBorder = PdfColor.fromInt(0xFFE2E5EA);
const _pdfSuccess = PdfColor.fromInt(0xFF1F8A5B);
const _pdfWarning = PdfColor.fromInt(0xFFD9A441);
const _pdfError = PdfColor.fromInt(0xFFC9473F);
const _pdfSurfaceMuted = PdfColor.fromInt(0xFFEFF1F4);

class FacturaPdfService {
  FacturaPdfService._();

  /// Se cargan una sola vez por proceso -- rootBundle.load() es la
  /// forma normal de leer un asset declarado en pubspec.yaml (nunca una
  /// petición de red: el archivo ya va empaquetado en el APK/IPA desde
  /// que se compiló). PT Sans (ParaType, licencia OFL -- ver
  /// assets/fonts/OFL.txt) se eligió porque, a diferencia de la
  /// Helvetica base del paquete `pdf`, sí incluye el glifo "€" y las
  /// vocales acentuadas/ñ en la misma fuente.
  static pw.ThemeData? _temaCacheado;

  static Future<pw.ThemeData> _tema() async {
    final cacheado = _temaCacheado;
    if (cacheado != null) return cacheado;
    pw.ThemeData tema;
    try {
      final regular = await rootBundle.load('assets/fonts/PTSans-Regular.ttf');
      final negrita = await rootBundle.load('assets/fonts/PTSans-Bold.ttf');
      tema = pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(negrita),
      );
    } catch (e, st) {
      // PT Sans va empaquetada en el APK/IPA (ver pubspec.yaml) -- un
      // fallo aquí sería un error de empaquetado, no una condición
      // esperada en producción. Se degrada a la fuente base del paquete
      // `pdf` (Helvetica, sin "€" ni acentos) en vez de impedir generar
      // el documento entero por un problema de tipografía.
      debugPrint(
        'FacturaPdfService: no se pudo cargar PT Sans, se usa la fuente '
        'base sin "€" ni acentos. $e\n$st',
      );
      tema = pw.ThemeData.base();
    }
    _temaCacheado = tema;
    return tema;
  }

  /// true si esta factura YA fue emitida pero no guarda una fotografía
  /// de los datos del emisor -- facturas creadas antes de la
  /// iteración 6. Nunca se rellena en silencio con los datos actuales
  /// de "Mi negocio"; la pantalla debe avisar explícitamente antes de
  /// generar un documento en este caso (ver invoice_detail_screen.dart).
  static bool faltanDatosHistoricosEmisor(Factura factura) =>
      factura.estado == EstadoFactura.emitida && factura.datosEmisor == null;

  /// Qué datos del emisor se usan para el documento, y si son un
  /// retrato histórico real o solo una vista previa de borrador:
  ///
  /// - Si la factura ya tiene su propia fotografía ([Factura.datosEmisor],
  ///   fijada una sola vez al emitir), se usa esa -- nunca la actual.
  /// - Si la factura es un BORRADOR, todavía no hay ninguna historia que
  ///   proteger: se usa el perfil actual de "Mi negocio" solo como
  ///   previsualización de cómo quedaría al emitir.
  /// - Si está emitida (o anulada) y no tiene fotografía propia, no se
  ///   usa el perfil actual bajo ningún concepto -- se deja en null y el
  ///   documento lo señala como un dato histórico ausente.
  static DatosNegocio? datosEmisorParaDocumento(
    Factura factura,
    DatosNegocio? datosNegocioActual,
  ) {
    if (factura.datosEmisor != null) return factura.datosEmisor;
    if (factura.estado == EstadoFactura.borrador) return datosNegocioActual;
    return null;
  }

  /// Mismo criterio que [datosEmisorParaDocumento], pero para el cliente
  /// (iteración 7.1) -- con una diferencia: a diferencia del emisor, no
  /// hay ninguna pantalla de "completar datos del cliente" ni se exige
  /// nada antes de emitir (ver ClienteSnapshot), así que esta función
  /// nunca necesita señalar un aviso bloqueante, solo resolver qué
  /// mostrar.
  static ClienteSnapshot? datosClienteParaDocumento(
    Factura factura,
    Cliente? clienteActual,
  ) {
    if (factura.datosCliente != null) return factura.datosCliente;
    if (factura.estado == EstadoFactura.borrador) {
      return clienteActual != null ? ClienteSnapshot.desde(clienteActual) : null;
    }
    return null;
  }

  /// Nombre de archivo seguro para cualquier sistema de archivos --
  /// "Factura_2026-0001.pdf" con el número real, o un nombre genérico
  /// para un borrador (que todavía no tiene número).
  static String nombreArchivo(Factura factura) {
    final base = factura.numero != null
        ? 'Factura_${factura.numero}'
        : 'Borrador_factura_${factura.id.substring(0, factura.id.length < 8 ? factura.id.length : 8)}';
    final seguro = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$seguro.pdf';
  }

  /// Genera el documento. No modifica la factura ni nada del repositorio
  /// -- es una función pura de los datos que recibe.
  ///
  /// [facturaOriginal] (iteración 8) es obligatorio cuando [factura] es
  /// una rectificativa -- quien llama la resuelve con
  /// `appData.facturas.byId(factura.facturaOriginalId)` (este servicio
  /// no conoce ningún repositorio, igual que ya pasa con [cliente]). Si
  /// falta, no se genera un documento incompleto que pueda confundirse
  /// con uno fiable: se lanza con un mensaje claro en vez de omitir en
  /// silencio la referencia a la factura rectificada.
  static Future<Uint8List> generar({
    required Factura factura,
    Cliente? cliente,
    DatosNegocio? datosNegocioActual,
    Factura? facturaOriginal,
  }) async {
    final esRectificativa = factura.tipoDocumento == TipoDocumentoFactura.rectificativa;
    if (esRectificativa && facturaOriginal == null) {
      throw StateError(
        'No se puede generar el PDF de la rectificativa: no se encuentra '
        'la factura original que corrige.',
      );
    }
    final datosEmisor = datosEmisorParaDocumento(factura, datosNegocioActual);
    final datosCliente = datosClienteParaDocumento(factura, cliente);
    final esBorrador = factura.estado == EstadoFactura.borrador;
    final esAnulada = factura.estado == EstadoFactura.anulada;
    final faltaHistorial = faltanDatosHistoricosEmisor(factura);
    final totales = factura.totales;

    final doc = pw.Document(
      title: factura.numero ?? 'Borrador de factura',
      author: datosEmisor?.nombreFiscal,
      theme: await _tema(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
        footer: (context) => _piePagina(context),
        build: (context) => [
          _cabecera(
            factura,
            esBorrador: esBorrador,
            esAnulada: esAnulada,
            esRectificativa: esRectificativa,
          ),
          pw.SizedBox(height: 18),
          if (esRectificativa) _bloqueRectificacion(factura, facturaOriginal!),
          if (faltaHistorial) _avisoDatosHistoricosFaltantes(),
          if (esBorrador) _avisoBorrador(),
          if (esAnulada) _avisoAnulada(factura),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _bloqueEmisor(datosEmisor)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _bloqueCliente(datosCliente)),
            ],
          ),
          pw.SizedBox(height: 20),
          _tablaConceptos(factura.conceptos),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 260,
              child: _bloqueTotales(factura, totales),
            ),
          ),
          if (factura.estado != EstadoFactura.borrador &&
              factura.pagos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _bloqueCobros(factura.pagos),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cabecera(
    Factura factura, {
    required bool esBorrador,
    required bool esAnulada,
    required bool esRectificativa,
  }) {
    final etiquetaEstado = esAnulada
        ? 'ANULADA'
        : esBorrador
        ? 'BORRADOR'
        : null;
    final colorEstado = esAnulada ? _pdfError : _pdfWarning;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          esRectificativa ? 'FACTURA RECTIFICATIVA' : 'FACTURA',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _pdfPrimary,
            letterSpacing: 1.2,
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              factura.numero ?? 'Sin número (borrador)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            if (factura.fechaEmision != null)
              pw.Text(
                'Emitida el ${formatDate(factura.fechaEmision!)}',
                style: const pw.TextStyle(fontSize: 9.5, color: _pdfInkMuted),
              ),
            if (factura.fechaVencimiento != null)
              pw.Text(
                'Vence el ${formatDate(factura.fechaVencimiento!)}',
                style: const pw.TextStyle(fontSize: 9.5, color: _pdfInkMuted),
              ),
            if (etiquetaEstado != null) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: colorEstado,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  etiquetaEstado,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _avisoBorrador() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: _pdfSurfaceMuted,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: _pdfBorder),
    ),
    child: pw.Text(
      'Documento de trabajo sin validez fiscal: todavía es un borrador, '
      'sin número asignado. Los datos del negocio mostrados son los '
      'actuales de "Mi negocio" y pueden cambiar hasta que se emita.',
      style: const pw.TextStyle(fontSize: 8.5, color: _pdfInkMuted),
    ),
  );

  static pw.Widget _avisoAnulada(Factura factura) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF5E6E4),
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: _pdfError),
    ),
    child: pw.Text(
      'Factura ANULADA'
      '${factura.fechaAnulacion != null ? ' el ${formatDate(factura.fechaAnulacion!)}' : ''}'
      '${factura.motivoAnulacion != null ? '. Motivo: ${factura.motivoAnulacion}' : ''}. '
      'No tiene validez como documento vigente.',
      style: pw.TextStyle(fontSize: 8.5, color: _pdfError, fontWeight: pw.FontWeight.bold),
    ),
  );

  /// Identifica sin ambigüedad qué factura se corrige y por qué (art.
  /// 15.4 RD 1619/2012: la rectificativa debe identificar la factura
  /// rectificada) -- [original] viene ya resuelto por quien llama
  /// (ver [generar]), nunca se recalcula ni se toca aquí.
  static pw.Widget _bloqueRectificacion(Factura factura, Factura original) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: _pdfSurfaceMuted,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: _pdfBorder),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Rectifica a la factura ${original.numero ?? "sin número"}'
          '${original.fechaEmision != null ? ', emitida el ${formatDate(original.fechaEmision!)}' : ''}.',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfInk),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Motivo: ${factura.motivoRectificacion?.trim().isNotEmpty ?? false ? factura.motivoRectificacion : "sin motivo indicado"}',
          style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
        ),
      ],
    ),
  );

  static pw.Widget _avisoDatosHistoricosFaltantes() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFFBF2E3),
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: _pdfWarning),
    ),
    child: pw.Text(
      'Aviso: esta factura se emitió antes de existir el registro de los '
      'datos del negocio en el momento de la emisión. No se dispone de '
      'esa fotografía histórica y, por integridad de los datos, no se '
      'sustituye por el perfil actual -- el apartado "Emisor" de este '
      'documento queda incompleto.',
      style: pw.TextStyle(fontSize: 8.5, color: _pdfAccentStrong, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _tituloBloque(String texto) => pw.Text(
    texto.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: _pdfInkMuted,
      letterSpacing: 1,
    ),
  );

  static pw.Widget _bloqueEmisor(DatosNegocio? d) {
    if (d == null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _tituloBloque('Emisor'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Datos del emisor no disponibles.',
            style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
          ),
        ],
      );
    }
    final lineasDomicilio = [
      d.direccion,
      [d.codigoPostal, d.localidad].where((s) => (s ?? '').isNotEmpty).join(' '),
      d.provincia,
      if ((d.pais).trim().toLowerCase() != 'españa') d.pais,
    ].where((s) => (s ?? '').trim().isNotEmpty).join(', ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloBloque('Emisor'),
        pw.SizedBox(height: 4),
        pw.Text(
          (d.nombreComercial?.trim().isNotEmpty ?? false)
              ? d.nombreComercial!
              : d.nombreFiscal,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _pdfInk),
        ),
        if ((d.nombreComercial?.trim().isNotEmpty ?? false))
          pw.Text(d.nombreFiscal, style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted)),
        if (d.nif.trim().isNotEmpty)
          pw.Text('NIF: ${d.nif}', style: const pw.TextStyle(fontSize: 9)),
        if (lineasDomicilio.isNotEmpty)
          pw.Text(lineasDomicilio, style: const pw.TextStyle(fontSize: 9)),
        if ((d.telefono ?? '').isNotEmpty)
          pw.Text('Tel: ${d.telefono}', style: const pw.TextStyle(fontSize: 9)),
        if ((d.email ?? '').isNotEmpty)
          pw.Text(d.email!, style: const pw.TextStyle(fontSize: 9)),
        if ((d.web ?? '').isNotEmpty)
          pw.Text(d.web!, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _bloqueCliente(ClienteSnapshot? cliente) {
    if (cliente == null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _tituloBloque('Cliente'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Datos del cliente no disponibles.',
            style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
          ),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloBloque('Cliente'),
        pw.SizedBox(height: 4),
        pw.Text(
          cliente.nombre,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _pdfInk),
        ),
        if ((cliente.direccion ?? '').isNotEmpty)
          pw.Text(cliente.direccion!, style: const pw.TextStyle(fontSize: 9)),
        if ((cliente.telefono ?? '').isNotEmpty)
          pw.Text('Tel: ${cliente.telefono}', style: const pw.TextStyle(fontSize: 9)),
        if ((cliente.email ?? '').isNotEmpty)
          pw.Text(cliente.email!, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static String _formatearCantidad(double c) =>
      c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

  /// Mismo importe que formatCurrency() -- misma cifra, mismo redondeo,
  /// nunca se recalcula nada aquí. Antes de incrustar PT Sans (ver
  /// _tema()) se sustituía "€" por "EUR" porque Helvetica no tenía ese
  /// glifo; ya no hace falta.
  static String _moneda(double v) => formatCurrency(v);

  static pw.Widget _tablaConceptos(List<ConceptoPresupuesto> conceptos) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Descripción', 'Cant.', 'Precio', 'Importe'],
      data: conceptos
          .map(
            (c) => [
              c.descripcion,
              _formatearCantidad(c.cantidad),
              _moneda(c.precioUnitario),
              _moneda(c.subtotal),
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _pdfPrimary),
      cellStyle: const pw.TextStyle(fontSize: 9.5, color: _pdfInk),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.6),
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: _pdfBorder, width: 0.5),
      ),
      cellHeight: 24,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _filaTotal(
    String etiqueta,
    double valor, {
    bool destacado = false,
    PdfColor? colorValor,
  }) {
    final estilo = pw.TextStyle(
      fontSize: destacado ? 12 : 9.5,
      fontWeight: destacado ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: colorValor ?? (destacado ? _pdfPrimary : _pdfInk),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Expanded -- etiquetas largas de rectificativa ("IMPORTE DE
          // LA RECTIFICACIÓN") en estilo destacado, dentro de un bloque
          // de ancho fijo (ver generar()), no deben superponerse con el
          // importe.
          pw.Expanded(child: pw.Text(etiqueta, style: estilo)),
          pw.Text(_moneda(valor), style: estilo),
        ],
      ),
    );
  }

  static pw.Widget _bloqueTotales(Factura factura, FacturaTotals totales) {
    final esRectificativa = factura.tipoDocumento == TipoDocumentoFactura.rectificativa;
    final esImporteResultante =
        factura.modalidadRectificacion == ModalidadRectificacion.importeResultante;
    // Art. 15.5 RD 1619/2012: en la modalidad "importe resultante" los
    // importes se muestran YA corregidos (no la diferencia), pero la
    // norma exige señalar igualmente el importe de la rectificación --
    // de ahí la fila aparte, nunca recalculada aquí (ver
    // Factura.importeRectificacion).
    final etiquetaTotal = !esRectificativa
        ? 'TOTAL'
        : esImporteResultante
        ? 'TOTAL (RECTIFICADO)'
        : 'IMPORTE DE LA RECTIFICACIÓN';
    final filas = <pw.Widget>[
      _filaTotal('Subtotal', totales.subtotalBruto),
      if (factura.descuentoPorcentaje > 0)
        _filaTotal(
          'Descuento (${factura.descuentoPorcentaje.toStringAsFixed(0)}%)',
          -totales.descuento,
        ),
      _filaTotal('Base imponible', totales.baseImponible),
      _filaTotal(
        'IVA (${factura.ivaPorcentaje.toStringAsFixed(0)}%)',
        totales.iva,
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Divider(color: _pdfBorder, height: 1),
      ),
      _filaTotal(etiquetaTotal, totales.total, destacado: true),
      if (esRectificativa && esImporteResultante)
        _filaTotal(
          'Importe de la rectificación',
          factura.importeRectificacion ?? 0,
          colorValor: _pdfAccentStrong,
        ),
    ];
    // Cobrado/pendiente no tienen sentido en una rectificativa -- nunca
    // registra cobros propios (ver FacturaRepository.registrarPago()),
    // el cobro sigue viviendo en la factura original.
    if (factura.estado != EstadoFactura.borrador && !esRectificativa) {
      filas.addAll([
        pw.SizedBox(height: 4),
        _filaTotal('Cobrado', factura.totalCobrado, colorValor: _pdfSuccess),
        _filaTotal(
          'Pendiente',
          factura.saldoPendiente,
          colorValor: factura.saldoPendiente > 0 ? _pdfWarning : _pdfSuccess,
        ),
      ]);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _pdfSurfaceMuted,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: filas),
    );
  }

  static pw.Widget _bloqueCobros(List<PagoFactura> pagos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloBloque('Historial de cobros'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Fecha', 'Método', 'Importe', 'Nota'],
          data: pagos
              .map(
                (p) => [
                  formatDate(p.fecha),
                  nombreMetodoPago(p.metodo),
                  _moneda(p.importe),
                  p.nota ?? '',
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _pdfInk),
          headerDecoration: const pw.BoxDecoration(color: _pdfSurfaceMuted),
          cellStyle: const pw.TextStyle(fontSize: 8.5, color: _pdfInk),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerLeft,
          },
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: pw.TableBorder(
            horizontalInside: const pw.BorderSide(color: _pdfBorder, width: 0.5),
          ),
        ),
      ],
    );
  }

  static pw.Widget _piePagina(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Text(
      'Página ${context.pageNumber} de ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: _pdfInkMuted),
    ),
  );
}
