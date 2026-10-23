// lib/features/invoices/invoice_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/demo_tag.dart';
import '../../data/app_data.dart';
import '../../data/models/datos_negocio.dart';
import '../../data/models/factura.dart';
import '../../data/models/pago_factura.dart';
import '../jobs/job_detail_screen.dart';
import '../quotes/quote_detail_screen.dart';
import '../settings/business_settings_screen.dart';
import 'invoice_form_screen.dart';
import 'payment_form_sheet.dart';

/// Etiqueta visible combinando el estado guardado (borrador/emitida/
/// anulada) con las propiedades calculadas a partir de los pagos y la
/// fecha de vencimiento -- ver nota en factura.dart sobre por qué estas
/// últimas nunca se guardan aparte.
String etiquetaFactura(Factura f, {DateTime? ahora}) {
  if (f.estado == EstadoFactura.borrador) return 'Borrador';
  if (f.estado == EstadoFactura.anulada) return 'Anulada';
  if (f.pagadaCompleta) return 'Pagada';
  if (f.estaVencida(ahora: ahora)) return 'Vencida';
  if (f.pagadaParcial) return 'Pago parcial';
  return 'Pendiente de cobro';
}

Color colorEstadoFactura(Factura f, {DateTime? ahora}) {
  if (f.estado == EstadoFactura.borrador) return AppColors.inkFaint;
  if (f.estado == EstadoFactura.anulada) return AppColors.error;
  if (f.pagadaCompleta) return AppColors.success;
  if (f.estaVencida(ahora: ahora)) return AppColors.error;
  if (f.pagadaParcial) return AppColors.warning;
  return AppColors.primary;
}

class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({
    required this.appData,
    required this.facturaId,
    super.key,
  });

  final AppData appData;
  final String facturaId;

  Future<void> _emitir(BuildContext context, Factura factura) async {
    // Se comprueba ANTES de pedir fecha de vencimiento ni confirmación
    // -- no tiene sentido hacer rellenar eso para descubrir después que
    // faltan datos del negocio (encargo iteración 6, sección 6).
    final datosNegocio = appData.negocio.datos;
    final faltan = datosNegocio?.camposFaltantesParaFacturar ??
        const DatosNegocio(nombreFiscal: '', nif: '').camposFaltantesParaFacturar;
    if (faltan.isNotEmpty) {
      final irANegocio = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Faltan datos de tu negocio'),
          content: Text(
            'Para emitir facturas hace falta completar en "Mi negocio":\n\n'
            '• ${faltan.join('\n• ')}\n\n'
            'El borrador se queda tal cual, puedes volver cuando quieras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ir a Mi negocio'),
            ),
          ],
        ),
      );
      if (irANegocio == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BusinessSettingsScreen(appData: appData)),
        );
      }
      return;
    }

    final fechaVencimiento = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Fecha de vencimiento (opcional, cancela para omitirla)',
    );
    if (!context.mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Emitir esta factura?'),
        content: Text(
          'Se le asignará número y pasará a estado "Emitida". A partir de '
          'ese momento, sus conceptos e importes ya no se pueden editar.\n\n'
          'Total: ${formatCurrency(factura.totales.total)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await appData.facturas.emitir(
        factura.id,
        fechaVencimiento: fechaVencimiento,
        datosEmisor: datosNegocio!,
      );
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _anular(BuildContext context, Factura factura) async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular factura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La factura y su número se conservan -- no se borra ni se '
              'reutiliza. Si hace falta volver a facturar, crea una '
              'factura nueva.',
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(labelText: 'Motivo *'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (motivo == null || motivo.trim().isEmpty) return;
    try {
      await appData.facturas.anular(factura.id, motivo);
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appData.facturas,
        appData.clientes,
        appData.trabajos,
        appData.presupuestos,
      ]),
      builder: (context, _) {
        final factura = appData.facturas.byId(facturaId);
        if (factura == null) {
          return const Scaffold(
            body: Center(child: Text('Esta factura ya no existe.')),
          );
        }
        final cliente = appData.clientes.byId(factura.clienteId);
        final trabajo = factura.trabajoId != null
            ? appData.trabajos.byId(factura.trabajoId!)
            : null;
        final presupuesto = factura.presupuestoId != null
            ? appData.presupuestos.byId(factura.presupuestoId!)
            : null;
        final color = colorEstadoFactura(factura);
        final totales = factura.totales;
        final esBorrador = factura.estado == EstadoFactura.borrador;
        final esEmitida = factura.estado == EstadoFactura.emitida;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    factura.numero ?? factura.titulo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (factura.esDemo) ...[
                  const SizedBox(width: 8),
                  const DemoTag(),
                ],
              ],
            ),
            actions: [
              if (esBorrador) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceFormScreen(
                        appData: appData,
                        clienteIdFijo: factura.clienteId,
                        trabajoIdFijo: factura.trabajoId,
                        presupuestoIdFijo: factura.presupuestoId,
                        existente: factura,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar este borrador?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmar == true) {
                      await appData.facturas.delete(facturaId);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(etiquetaFactura(factura)),
                    backgroundColor: color.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    factura.fechaEmision != null
                        ? formatDate(factura.fechaEmision!)
                        : 'Sin emitir',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                cliente?.nombre ?? 'Cliente eliminado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (factura.fechaVencimiento != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Vence el ${formatDate(factura.fechaVencimiento!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (factura.datosEmisor != null) ...[
                const SizedBox(height: 2),
                Text(
                  // Siempre el nombre/NIF con el que se emitió, aunque
                  // "Mi negocio" se haya cambiado después -- ver nota en
                  // Factura.datosEmisor.
                  'Emitida por: ${factura.datosEmisor!.nombreFiscal} '
                  '(${factura.datosEmisor!.nif})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < factura.conceptos.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        title: Text(factura.conceptos[i].descripcion),
                        subtitle: Text(
                          '${_formatearCantidad(factura.conceptos[i].cantidad)} '
                          '× ${formatCurrency(factura.conceptos[i].precioUnitario)}',
                        ),
                        trailing: Text(
                          formatCurrency(factura.conceptos[i].subtotal),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(
                    children: [
                      _FilaTotalDetalle('Subtotal', totales.subtotalBruto),
                      if (factura.descuentoPorcentaje > 0)
                        _FilaTotalDetalle(
                          'Descuento (${factura.descuentoPorcentaje.toStringAsFixed(0)}%)',
                          -totales.descuento,
                        ),
                      _FilaTotalDetalle('Base imponible', totales.baseImponible),
                      _FilaTotalDetalle(
                        'IVA (${factura.ivaPorcentaje.toStringAsFixed(0)}%)',
                        totales.iva,
                      ),
                      const Divider(height: AppSpace.lg),
                      _FilaTotalDetalle('Total', totales.total, destacado: true),
                      if (esEmitida) ...[
                        const SizedBox(height: AppSpace.xs),
                        _FilaTotalDetalle('Cobrado', factura.totalCobrado),
                        _FilaTotalDetalle(
                          'Pendiente',
                          factura.saldoPendiente,
                          resaltarSiPositivo: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (esBorrador) ...[
                const SizedBox(height: AppSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _emitir(context, factura),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Emitir factura'),
                  ),
                ),
              ],
              if (esEmitida) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Historial de cobros',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                if (factura.pagos.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Text(
                        'Todavía no se ha registrado ningún cobro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < factura.pagos.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: const Icon(
                              Icons.payments_outlined,
                              color: AppColors.success,
                            ),
                            title: Text(formatCurrency(factura.pagos[i].importe)),
                            subtitle: Text(
                              '${formatDate(factura.pagos[i].fecha)} · '
                              '${nombreMetodoPago(factura.pagos[i].metodo)}'
                              '${factura.pagos[i].nota != null ? ' · ${factura.pagos[i].nota}' : ''}',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (factura.saldoPendiente > 0) ...[
                  const SizedBox(height: AppSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          mostrarFormularioPago(context, appData: appData, factura: factura),
                      icon: const Icon(Icons.add_card_outlined, size: 18),
                      label: const Text('Registrar cobro'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _anular(context, factura),
                    icon: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('Anular factura'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
              if (factura.estado == EstadoFactura.anulada &&
                  factura.motivoAnulacion != null) ...[
                const SizedBox(height: AppSpace.lg),
                Card(
                  color: AppColors.errorTint,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anulada el ${formatDate(factura.fechaAnulacion!)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(factura.motivoAnulacion!),
                      ],
                    ),
                  ),
                ),
              ],
              if (trabajo != null || presupuesto != null) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Origen',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                if (trabajo != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.build_outlined),
                      title: const Text('Trabajo'),
                      subtitle: Text(trabajo.titulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              JobDetailScreen(appData: appData, trabajoId: trabajo.id),
                        ),
                      ),
                    ),
                  ),
                if (presupuesto != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.request_quote_outlined),
                      title: const Text('Presupuesto'),
                      subtitle: Text(presupuesto.titulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuoteDetailScreen(
                            appData: appData,
                            presupuestoId: presupuesto.id,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _formatearCantidad(double c) =>
    c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toString();

class _FilaTotalDetalle extends StatelessWidget {
  const _FilaTotalDetalle(
    this.label,
    this.valor, {
    this.destacado = false,
    this.resaltarSiPositivo = false,
  });

  final String label;
  final double valor;
  final bool destacado;
  final bool resaltarSiPositivo;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.primary)
        : resaltarSiPositivo && valor > 0
        ? Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatCurrency(valor), style: style),
        ],
      ),
    );
  }
}
