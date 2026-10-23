// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/demo_data_banner.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/quick_action_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../../data/app_data.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/trabajo.dart';
import '../calendar/appointment_form_sheet.dart';
import '../clients/client_form_sheet.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_sheet.dart';
import '../quotes/quote_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.appData,
    required this.onVerTrabajos,
    required this.onVerPresupuestos,
    super.key,
  });

  final AppData appData;
  final VoidCallback onVerTrabajos;
  final VoidCallback onVerPresupuestos;

  void _nuevoPresupuesto(BuildContext context) {
    if (appData.clientes.clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Crea antes un cliente para poder hacerle un presupuesto.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuoteFormScreen(appData: appData)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          appData.clientes,
          appData.trabajos,
          appData.presupuestos,
          appData.citas,
        ]),
        builder: (context, _) {
          final trabajos = appData.trabajos.trabajos;
          final presupuestos = appData.presupuestos.presupuestos;
          final hayDatosDemo =
              appData.clientes.clientes.any((c) => c.esDemo) ||
              trabajos.any((t) => t.esDemo) ||
              presupuestos.any((p) => p.esDemo) ||
              appData.citas.citas.any((c) => c.esDemo);
          final enCurso = trabajos
              .where((t) => t.estado == EstadoTrabajo.enCurso)
              .length;
          final pendientes = trabajos
              .where((t) => t.estado == EstadoTrabajo.pendiente)
              .length;
          final presupuestosEnviados = presupuestos
              .where((p) => p.estado == EstadoPresupuesto.enviado)
              .length;
          final ingresosPrevistos = presupuestos
              .where((p) => p.estado == EstadoPresupuesto.aceptado)
              .fold<double>(0, (acc, p) => acc + p.totales.total);
          // Aceptados sin trabajo todavía -- el siguiente paso pendiente
          // del flujo presupuesto -> trabajo (encargo, iteración 3).
          final aceptadosSinTrabajo = presupuestos
              .where(
                (p) =>
                    p.estado == EstadoPresupuesto.aceptado &&
                    appData.trabajos.porPresupuesto(p.id).isEmpty,
              )
              .length;

          final proximasCitas =
              appData.citas.citas
                  .where(
                    (c) =>
                        !c.completada &&
                        c.fechaHora.isAfter(
                          DateTime.now().subtract(const Duration(hours: 1)),
                        ),
                  )
                  .toList()
                ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

          final proximosTrabajos =
              trabajos
                  .where(
                    (t) =>
                        t.fechaProgramada != null &&
                        t.fechaProgramada!.isAfter(
                          DateTime.now().subtract(const Duration(days: 1)),
                        ) &&
                        t.estado != EstadoTrabajo.cancelado,
                  )
                  .toList()
                ..sort(
                  (a, b) => a.fechaProgramada!.compareTo(b.fechaProgramada!),
                );

          final actividad = _actividadReciente(appData);

          return ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Text(
                'Hola de nuevo',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Esto es lo que tienes entre manos hoy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (hayDatosDemo) ...[
                const SizedBox(height: AppSpace.md),
                const DemoDataBanner(),
              ],
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  QuickActionButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Cliente',
                    onTap: () => mostrarFormularioCliente(
                      context,
                      repo: appData.clientes,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  QuickActionButton(
                    icon: Icons.build_outlined,
                    label: 'Trabajo',
                    onTap: () =>
                        mostrarFormularioTrabajo(context, appData: appData),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  QuickActionButton(
                    icon: Icons.request_quote_outlined,
                    label: 'Presupuesto',
                    onTap: () => _nuevoPresupuesto(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpace.sm,
                crossAxisSpacing: AppSpace.sm,
                childAspectRatio: 1.5,
                children: [
                  StatTile(
                    icon: Icons.build_outlined,
                    value: '$enCurso',
                    label: 'Trabajos en curso',
                    color: AppColors.primary,
                    onTap: onVerTrabajos,
                  ),
                  StatTile(
                    icon: Icons.pending_actions_outlined,
                    value: '$pendientes',
                    label: 'Trabajos pendientes',
                    color: AppColors.warning,
                    onTap: onVerTrabajos,
                  ),
                  StatTile(
                    icon: Icons.mark_email_read_outlined,
                    value: '$presupuestosEnviados',
                    label: 'Presupuestos esperando respuesta',
                    color: AppColors.accentStrong,
                    onTap: onVerPresupuestos,
                  ),
                  StatTile(
                    icon: Icons.payments_outlined,
                    value: formatCurrency(ingresosPrevistos),
                    label: 'Ingresos previstos (aceptados)',
                    color: AppColors.success,
                    onTap: onVerPresupuestos,
                  ),
                  StatTile(
                    icon: Icons.arrow_forward_outlined,
                    value: '$aceptadosSinTrabajo',
                    label: 'Aceptados sin trabajo creado',
                    color: AppColors.accentStrong,
                    onTap: onVerPresupuestos,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              SectionHeader(
                title: 'Próximos trabajos',
                actionLabel: proximosTrabajos.isEmpty ? null : 'Ver todos',
                onAction: proximosTrabajos.isEmpty ? null : onVerTrabajos,
              ),
              const SizedBox(height: AppSpace.sm),
              if (proximosTrabajos.isEmpty)
                _TarjetaVacia(
                  texto: 'No tienes trabajos programados próximamente.',
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < proximosTrabajos.length.clamp(0, 4); i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.primary,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  proximosTrabajos[i].titulo,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (proximosTrabajos[i].esDemo) ...[
                                const SizedBox(width: 6),
                                const DemoTag(),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            formatDate(proximosTrabajos[i].fechaProgramada!),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(
                                appData: appData,
                                trabajoId: proximosTrabajos[i].id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Próximas citas'),
              const SizedBox(height: AppSpace.sm),
              if (proximasCitas.isEmpty)
                const _TarjetaVacia(texto: 'No tienes citas programadas.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < proximasCitas.length.clamp(0, 4); i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: const Icon(
                            Icons.event_outlined,
                            color: AppColors.primary,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  proximasCitas[i].titulo,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (proximasCitas[i].esDemo) ...[
                                const SizedBox(width: 6),
                                const DemoTag(),
                              ],
                            ],
                          ),
                          subtitle: Text(formatDateTime(proximasCitas[i].fechaHora)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => mostrarFormularioCita(
                            context,
                            appData: appData,
                            existente: proximasCitas[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Actividad reciente'),
              const SizedBox(height: AppSpace.sm),
              if (actividad.isEmpty)
                const _TarjetaVacia(texto: 'Todavía no hay actividad.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < actividad.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: Icon(
                            actividad[i].icono,
                            color: AppColors.inkMuted,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  actividad[i].texto,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (actividad[i].esDemo) ...[
                                const SizedBox(width: 6),
                                const DemoTag(),
                              ],
                            ],
                          ),
                          trailing: Text(
                            formatDate(actividad[i].fecha),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventoActividad {
  const _EventoActividad({
    required this.icono,
    required this.texto,
    required this.fecha,
    required this.esDemo,
  });

  final IconData icono;
  final String texto;
  final DateTime fecha;
  final bool esDemo;
}

List<_EventoActividad> _actividadReciente(AppData appData) {
  final eventos = <_EventoActividad>[
    for (final c in appData.clientes.clientes)
      _EventoActividad(
        icono: Icons.person_add_alt_1_outlined,
        texto: 'Nuevo cliente: ${c.nombre}',
        fecha: c.creadoEl,
        esDemo: c.esDemo,
      ),
    for (final t in appData.trabajos.trabajos)
      _EventoActividad(
        icono: Icons.build_outlined,
        texto: 'Nuevo trabajo: ${t.titulo}',
        fecha: t.creadoEl,
        esDemo: t.esDemo,
      ),
    for (final p in appData.presupuestos.presupuestos)
      _EventoActividad(
        icono: Icons.request_quote_outlined,
        texto: 'Presupuesto creado: ${p.titulo}',
        fecha: p.creadoEl,
        esDemo: p.esDemo,
      ),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  return eventos.take(6).toList();
}

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
