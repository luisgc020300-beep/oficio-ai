// lib/features/jobs/job_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/demo_tag.dart';
import '../../data/app_data.dart';
import '../../data/models/concepto_presupuesto.dart';
import '../../data/models/trabajo.dart';
import '../calendar/appointment_form_sheet.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_form_screen.dart';
import '../quotes/quote_detail_screen.dart';
import 'job_form_sheet.dart';

Color _colorEstadoTrabajo(EstadoTrabajo e) => switch (e) {
  EstadoTrabajo.pendiente => AppColors.warning,
  EstadoTrabajo.enCurso => AppColors.primary,
  EstadoTrabajo.finalizado => AppColors.success,
  EstadoTrabajo.cancelado => AppColors.inkFaint,
};

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({
    required this.appData,
    required this.trabajoId,
    super.key,
  });

  final AppData appData;
  final String trabajoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appData.trabajos,
        appData.clientes,
        appData.presupuestos,
        appData.citas,
        appData.facturas,
      ]),
      builder: (context, _) {
        final trabajo = appData.trabajos.byId(trabajoId);
        if (trabajo == null) {
          return const Scaffold(
            body: Center(child: Text('Este trabajo ya no existe.')),
          );
        }
        final cliente = appData.clientes.byId(trabajo.clienteId);
        final presupuesto = trabajo.presupuestoId != null
            ? appData.presupuestos.byId(trabajo.presupuestoId!)
            : null;
        final citas = appData.citas.porTrabajo(trabajo.id)
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        final facturas = appData.facturas.porTrabajo(trabajo.id)
          ..sort((a, b) => b.creadaEl.compareTo(a.creadaEl));
        final color = _colorEstadoTrabajo(trabajo.estado);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(trabajo.titulo, overflow: TextOverflow.ellipsis),
                ),
                if (trabajo.esDemo) ...[
                  const SizedBox(width: 8),
                  const DemoTag(),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => mostrarFormularioTrabajo(
                  context,
                  appData: appData,
                  clienteId: trabajo.clienteId,
                  existente: trabajo,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmar = await confirmarEliminar(
                    context,
                    titulo: '¿Eliminar este trabajo?',
                  );
                  if (confirmar) {
                    await appData.trabajos.delete(trabajoId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => mostrarFormularioCita(
              context,
              appData: appData,
              clienteIdFijo: trabajo.clienteId,
              trabajoIdFijo: trabajo.id,
              tituloInicial: trabajo.titulo,
            ),
            icon: const Icon(Icons.event_outlined),
            label: const Text('Programar visita'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(nombreEstadoTrabajo(trabajo.estado)),
                    backgroundColor: color.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide.none,
                  ),
                  if (trabajo.fechaProgramada != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      formatDate(trabajo.fechaProgramada!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              _AccionesEstado(appData: appData, trabajo: trabajo),
              const SizedBox(height: AppSpace.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 17,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            cliente?.nombre ?? 'Cliente eliminado',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (trabajo.direccion != null) ...[
                        const SizedBox(height: AppSpace.sm),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 17,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(child: Text(trabajo.direccion!)),
                          ],
                        ),
                      ],
                      if (trabajo.descripcion != null) ...[
                        const Divider(height: AppSpace.lg),
                        Text(
                          trabajo.descripcion!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Presupuesto',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpace.sm),
              if (presupuesto == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      'Este trabajo todavía no tiene presupuesto asociado.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Card(
                  child: ListTile(
                    title: Text(presupuesto.titulo),
                    subtitle: Text(formatCurrency(presupuesto.totales.total)),
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
              const SizedBox(height: AppSpace.lg),
              Text('Facturas', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              if (facturas.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      trabajo.estado == EstadoTrabajo.finalizado
                          ? 'Este trabajo todavía no tiene factura.'
                          : 'Se podrá facturar cuando el trabajo esté terminado.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < facturas.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: Icon(
                            Icons.receipt_long_outlined,
                            color: colorEstadoFactura(facturas[i]),
                          ),
                          title: Text(facturas[i].numero ?? facturas[i].titulo),
                          subtitle: Text(
                            '${etiquetaFactura(facturas[i])} · '
                            '${formatCurrency(facturas[i].totales.total)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvoiceDetailScreen(
                                appData: appData,
                                facturaId: facturas[i].id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (trabajo.estado == EstadoTrabajo.finalizado) ...[
                const SizedBox(height: AppSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceFormScreen(
                          appData: appData,
                          clienteIdFijo: trabajo.clienteId,
                          trabajoIdFijo: trabajo.id,
                          presupuestoIdFijo: trabajo.presupuestoId,
                          tituloInicial: 'Factura · ${trabajo.titulo}',
                          conceptosIniciales: presupuesto?.conceptos
                              .map(
                                (c) => ConceptoPresupuesto(
                                  id: c.id,
                                  descripcion: c.descripcion,
                                  cantidad: c.cantidad,
                                  precioUnitario: c.precioUnitario,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(facturas.isEmpty ? 'Crear factura' : 'Crear otra factura'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              Text(
                'Citas programadas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpace.sm),
              if (citas.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      'Sin visitas programadas todavía.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < citas.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: Icon(
                            citas[i].completada
                                ? Icons.check_circle_outline
                                : Icons.event_outlined,
                            color: citas[i].completada
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          title: Text(citas[i].titulo),
                          subtitle: Text(formatDateTime(citas[i].fechaHora)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => mostrarFormularioCita(
                            context,
                            appData: appData,
                            existente: citas[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // Botón extra, no solo el FAB -- en listas largas el FAB
              // puede quedar tapado por el teclado o fuera de la vista
              // visible en pantallas pequeñas.
              if (citas.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => mostrarFormularioCita(
                    context,
                    appData: appData,
                    clienteIdFijo: trabajo.clienteId,
                    trabajoIdFijo: trabajo.id,
                    tituloInicial: trabajo.titulo,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Programar otra visita'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Botones de cambio de estado directos desde la ficha -- antes solo se
/// podía cambiar el estado abriendo el formulario de edición completo.
/// Nunca toca presupuesto ni citas: solo llama a
/// appData.trabajos.update() con el propio trabajo.
class _AccionesEstado extends StatelessWidget {
  const _AccionesEstado({required this.appData, required this.trabajo});

  final AppData appData;
  final Trabajo trabajo;

  Future<void> _cambiarA(
    BuildContext context,
    EstadoTrabajo nuevo, {
    String? tituloConfirmacion,
    String? mensajeConfirmacion,
  }) async {
    if (tituloConfirmacion != null) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tituloConfirmacion),
          content: mensajeConfirmacion != null
              ? Text(mensajeConfirmacion)
              : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }
    await appData.trabajos.update(trabajo.copyWith(estado: nuevo));
  }

  @override
  Widget build(BuildContext context) {
    switch (trabajo.estado) {
      case EstadoTrabajo.pendiente:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _cambiarA(context, EstadoTrabajo.enCurso),
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('Empezar trabajo'),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            OutlinedButton(
              onPressed: () => _cambiarA(
                context,
                EstadoTrabajo.cancelado,
                tituloConfirmacion: '¿Cancelar este trabajo?',
              ),
              child: const Text('Cancelar'),
            ),
          ],
        );
      case EstadoTrabajo.enCurso:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _cambiarA(
                  context,
                  EstadoTrabajo.finalizado,
                  tituloConfirmacion: '¿Marcar como terminado?',
                  mensajeConfirmacion:
                      'El presupuesto y las citas no cambian, solo el '
                      'estado del trabajo.',
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Marcar como terminado'),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            OutlinedButton(
              onPressed: () => _cambiarA(
                context,
                EstadoTrabajo.cancelado,
                tituloConfirmacion: '¿Cancelar este trabajo?',
              ),
              child: const Text('Cancelar'),
            ),
          ],
        );
      case EstadoTrabajo.finalizado:
      case EstadoTrabajo.cancelado:
        // Estados finales -- sin acción rápida; si hace falta corregirlo
        // (p. ej. se canceló por error), se hace desde "Editar".
        return const SizedBox.shrink();
    }
  }
}
