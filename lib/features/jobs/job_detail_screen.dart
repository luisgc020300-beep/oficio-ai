// lib/features/jobs/job_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/demo_tag.dart';
import '../../data/app_data.dart';
import '../../data/models/trabajo.dart';
import '../calendar/appointment_form_sheet.dart';
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
