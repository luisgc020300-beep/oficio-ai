// lib/features/jobs/jobs_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/trabajo.dart';
import 'job_detail_screen.dart';
import 'job_form_sheet.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  EstadoTrabajo? _filtro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostrarFormularioTrabajo(context, appData: widget.appData),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.appData.trabajos,
          widget.appData.clientes,
        ]),
        builder: (context, _) {
          final todos = widget.appData.trabajos.trabajos;
          if (todos.isEmpty) {
            return EmptyState(
              icon: Icons.work_outline,
              title: 'Todavía no hay trabajos',
              message: 'Crea el primero asociándolo a un cliente.',
              actionLabel: 'Nuevo trabajo',
              onAction: () =>
                  mostrarFormularioTrabajo(context, appData: widget.appData),
            );
          }
          final filtrados = _filtro == null
              ? todos
              : todos.where((t) => t.estado == _filtro).toList();
          return Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  children: [
                    _ChipFiltro(
                      label: 'Todos',
                      seleccionado: _filtro == null,
                      onTap: () => setState(() => _filtro = null),
                    ),
                    for (final e in EstadoTrabajo.values) ...[
                      const SizedBox(width: AppSpace.sm),
                      _ChipFiltro(
                        label: nombreEstadoTrabajo(e),
                        seleccionado: _filtro == e,
                        onTap: () => setState(() => _filtro = e),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_list_off,
                        title: 'Sin trabajos en este estado',
                        message: 'Prueba a cambiar el filtro de arriba.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.sm,
                          0,
                          AppSpace.sm,
                          AppSpace.lg,
                        ),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) =>
                            const Divider(indent: 68, height: 1),
                        itemBuilder: (context, i) {
                          final t = filtrados[i];
                          final cliente = widget.appData.clientes.byId(
                            t.clienteId,
                          );
                          return AppListTile(
                            icon: Icons.build_outlined,
                            iconColor: switch (t.estado) {
                              EstadoTrabajo.pendiente => AppColors.warning,
                              EstadoTrabajo.enCurso => AppColors.primary,
                              EstadoTrabajo.finalizado => AppColors.success,
                              EstadoTrabajo.cancelado => AppColors.inkFaint,
                            },
                            title: t.titulo,
                            esDemo: t.esDemo,
                            subtitle: cliente?.nombre ?? 'Sin cliente',
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.inkFaint,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                  appData: widget.appData,
                                  trabajoId: t.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
    );
  }
}
