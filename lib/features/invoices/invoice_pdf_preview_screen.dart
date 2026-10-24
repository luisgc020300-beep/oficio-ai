// lib/features/invoices/invoice_pdf_preview_screen.dart
//
// Vista previa del PDF de una factura. Solo lee datos -- no emite, no
// numera, no registra cobros ni cambia nada de la factura; genera los
// bytes bajo demanda con FacturaPdfService y se los pasa a PdfPreview
// (paquete `printing`), que ya trae zoom, paginación, imprimir y
// compartir integrados, así que no hay que reconstruir nada de eso a
// mano aquí.
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_data.dart';
import '../../data/models/factura.dart';
import '../../services/factura_pdf_service.dart';

class InvoicePdfPreviewScreen extends StatelessWidget {
  const InvoicePdfPreviewScreen({
    required this.appData,
    required this.factura,
    super.key,
  });

  final AppData appData;
  final Factura factura;

  @override
  Widget build(BuildContext context) {
    final cliente = appData.clientes.byId(factura.clienteId);
    final nombreArchivo = FacturaPdfService.nombreArchivo(factura);
    final facturaOriginal = factura.facturaOriginalId != null
        ? appData.facturas.byId(factura.facturaOriginalId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(factura.numero ?? 'Vista previa del borrador'),
      ),
      body: Column(
        children: [
          if (FacturaPdfService.faltanDatosHistoricosEmisor(factura))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.sm + 4),
              color: AppColors.warningTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined, size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Esta factura se emitió antes de guardar los datos del '
                      'negocio en el momento de emisión. El documento queda '
                      'incompleto en el apartado del emisor -- no se rellena '
                      'con los datos actuales de "Mi negocio" para no alterar '
                      'un documento histórico.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfPreview(
              build: (format) => FacturaPdfService.generar(
                factura: factura,
                cliente: cliente,
                datosNegocioActual: appData.negocio.datos,
                facturaOriginal: facturaOriginal,
              ),
              pdfFileName: nombreArchivo,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              useActions: true,
              allowPrinting: true,
              allowSharing: true,
              loadingWidget: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
