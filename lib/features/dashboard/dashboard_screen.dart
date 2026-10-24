// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/demo_data_banner.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/quick_action_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../../data/app_data.dart';
import '../../data/models/cita.dart';
import '../../data/models/factura.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/trabajo.dart';
import '../calendar/appointment_form_sheet.dart';
import '../clients/client_form_sheet.dart';
import '../expenses/expenses_list_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_sheet.dart';
import '../quotes/quote_form_screen.dart';
import '../settings/business_settings_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.appData,
    required this.onVerTrabajos,
    required this.onVerPresupuestos,
    required this.onVerFacturas,
    this.themeController,
    super.key,
  });

  final AppData appData;
  final ThemeController? themeController;
  final VoidCallback onVerTrabajos;
  final VoidCallback onVerPresupuestos;
  final VoidCallback onVerFacturas;

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
            tooltip: 'Gastos',
            icon: const Icon(Icons.receipt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ExpensesListScreen(appData: appData)),
            ),
          ),
          IconButton(
            tooltip: 'Mi negocio',
            icon: const Icon(Icons.store_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BusinessSettingsScreen(appData: appData)),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  appData: appData,
                  themeController: themeController ?? ThemeController(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          appData.clientes,
          appData.trabajos,
          appData.presupuestos,
          appData.citas,
          appData.facturas,
        ]),
        builder: (context, _) {
          final trabajos = appData.trabajos.trabajos;
          final presupuestos = appData.presupuestos.presupuestos;
          final facturas = appData.facturas.facturas;
          final hayDatosDemo =
              appData.clientes.clientes.any((c) => c.esDemo) ||
              trabajos.any((t) => t.esDemo) ||
              presupuestos.any((p) => p.esDemo) ||
              appData.citas.citas.any((c) => c.esDemo) ||
              facturas.any((f) => f.esDemo);
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

          // Resumen económico (encargo, iteración 5, sección 8). La
          // facturación se agrupa por fecha de EMISIÓN; los cobros, por
          // fecha EFECTIVA del pago -- son fechas distintas a propósito,
          // nunca se mezclan en el mismo cálculo.
          final hoyEconomico = DateTime.now();
          final inicioMes = DateTime(hoyEconomico.year, hoyEconomico.month);
          final inicioMesSiguiente = DateTime(
            hoyEconomico.year,
            hoyEconomico.month + 1,
          );
          // f.importeFacturacion, no f.totales.total: una rectificativa
          // en modalidad "importe resultante" declara el importe YA
          // corregido (no la diferencia) -- sumar eso junto al importe
          // sin cambios de la original contaría la operación dos veces
          // (iteración 8, ver Factura.importeFacturacion).
          final totalFacturadoMes = facturas
              .where(
                (f) =>
                    f.estado == EstadoFactura.emitida &&
                    f.fechaEmision != null &&
                    !f.fechaEmision!.isBefore(inicioMes) &&
                    f.fechaEmision!.isBefore(inicioMesSiguiente),
              )
              .fold<double>(0, (acc, f) => acc + f.importeFacturacion);
          final totalCobradoMes = facturas
              .expand((f) => f.pagos)
              .where(
                (p) =>
                    !p.fecha.isBefore(inicioMes) &&
                    p.fecha.isBefore(inicioMesSiguiente),
              )
              .fold<double>(0, (acc, p) => acc + p.importe);
          final saldoPendienteTotal = facturas
              .where((f) => f.estado == EstadoFactura.emitida)
              .fold<double>(0, (acc, f) => acc + f.saldoPendiente);
          // Por fecha del GASTO, no por fecha de registro en la app --
          // mismo criterio que fechaEmision para la facturación (encargo
          // iteración 9, sección 5). Solo los activos: uno anulado nunca
          // computa (ver Gasto.estado).
          final totalGastadoMes = appData.gastos.activos
              .where(
                (g) => !g.fecha.isBefore(inicioMes) && g.fecha.isBefore(inicioMesSiguiente),
              )
              .fold<double>(0, (acc, g) => acc + g.importe);
          // Estimación simple del mismo mes -- facturado menos gastado
          // en ese mismo periodo. No es el margen real de ningún
          // trabajo concreto (eso vive en job_detail_screen.dart,
          // donde sí se puede atribuir cada gasto a su trabajo): aquí
          // se mezclan los gastos de todos los trabajos con la
          // facturación de todos ellos, así que solo tiene sentido como
          // una cifra agregada del mes, nunca como "beneficio neto"
          // (faltan costes indirectos, impuestos, etc.).
          final margenEstimadoMes = totalFacturadoMes - totalGastadoMes;
          final facturasPendientes = facturas
              .where((f) => f.estado == EstadoFactura.emitida && !f.pagadaCompleta)
              .length;
          final facturasVencidas = facturas
              .where((f) => f.estaVencida(ahora: hoyEconomico))
              .length;
          // No cuenta como "sin facturar" si ya hay una factura EMITIDA
          // desde ese presupuesto -- un borrador en marcha no basta,
          // igual que appData.trabajos.porPresupuesto() arriba no cuenta
          // borradores de presupuesto como si ya hubiera trabajo.
          final presupuestosAceptadosSinFacturar = presupuestos
              .where(
                (p) =>
                    p.estado == EstadoPresupuesto.aceptado &&
                    appData.facturas
                        .porPresupuesto(p.id)
                        .where((f) => f.estado == EstadoFactura.emitida)
                        .isEmpty,
              )
              .length;
          final evolucionMensual = List.generate(6, (i) {
            final mes = DateTime(
              hoyEconomico.year,
              hoyEconomico.month - (5 - i),
            );
            final inicio = DateTime(mes.year, mes.month);
            final finExclusive = DateTime(mes.year, mes.month + 1);
            final facturado = facturas
                .where(
                  (f) =>
                      f.estado == EstadoFactura.emitida &&
                      f.fechaEmision != null &&
                      !f.fechaEmision!.isBefore(inicio) &&
                      f.fechaEmision!.isBefore(finExclusive),
                )
                .fold<double>(0, (acc, f) => acc + f.importeFacturacion);
            final cobrado = facturas
                .expand((f) => f.pagos)
                .where(
                  (p) => !p.fecha.isBefore(inicio) && p.fecha.isBefore(finExclusive),
                )
                .fold<double>(0, (acc, p) => acc + p.importe);
            return _MesEconomico(mes: mes, facturado: facturado, cobrado: cobrado);
          });

          final ahora = DateTime.now();
          final finDeHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
          // "Citas de hoy" tiene su propia sección (prioridad nº1 del
          // dashboard, encargo iteración 4) -- "Próximas citas" muestra
          // solo lo que viene DESPUÉS de hoy para no duplicar la cuenta.
          final citasHoy =
              appData.citas.citas
                  .where(
                    (c) =>
                        c.fechaHora.year == ahora.year &&
                        c.fechaHora.month == ahora.month &&
                        c.fechaHora.day == ahora.day,
                  )
                  .toList()
                ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
          final proximasCitas =
              appData.citas.citas
                  .where((c) => !c.completada && c.fechaHora.isAfter(finDeHoy))
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
              const SectionHeader(title: 'Hoy'),
              const SizedBox(height: AppSpace.sm),
              if (citasHoy.isEmpty)
                _TarjetaVacia(
                  texto: 'Sin citas programadas para hoy.',
                  accion: 'Programar cita',
                  onAccion: () => mostrarFormularioCita(
                    context,
                    appData: appData,
                    diaInicial: DateTime.now(),
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < citasHoy.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _FilaCitaHoy(appData: appData, cita: citasHoy[i]),
                      ],
                    ],
                  ),
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
                    icon: Icons.pending_actions_outlined,
                    value: '$pendientes',
                    label: 'Trabajos pendientes',
                    color: AppColors.warning,
                    onTap: onVerTrabajos,
                  ),
                  StatTile(
                    icon: Icons.build_outlined,
                    value: '$enCurso',
                    label: 'Trabajos en curso',
                    color: AppColors.primary,
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
                title: 'Resumen económico',
                actionLabel: 'Ver facturas',
                onAction: onVerFacturas,
              ),
              const SizedBox(height: AppSpace.sm),
              _ResumenEconomico(
                totalFacturadoMes: totalFacturadoMes,
                totalCobradoMes: totalCobradoMes,
                totalGastadoMes: totalGastadoMes,
                margenEstimadoMes: margenEstimadoMes,
                saldoPendienteTotal: saldoPendienteTotal,
                facturasPendientes: facturasPendientes,
                facturasVencidas: facturasVencidas,
                presupuestosAceptadosSinFacturar: presupuestosAceptadosSinFacturar,
                evolucionMensual: evolucionMensual,
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
                          leading: Icon(
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
                          leading: Icon(
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

class _MesEconomico {
  const _MesEconomico({
    required this.mes,
    required this.facturado,
    required this.cobrado,
  });

  final DateTime mes;
  final double facturado;
  final double cobrado;
}

const _mesesCorto = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

class _ResumenEconomico extends StatelessWidget {
  const _ResumenEconomico({
    required this.totalFacturadoMes,
    required this.totalCobradoMes,
    required this.totalGastadoMes,
    required this.margenEstimadoMes,
    required this.saldoPendienteTotal,
    required this.facturasPendientes,
    required this.facturasVencidas,
    required this.presupuestosAceptadosSinFacturar,
    required this.evolucionMensual,
  });

  final double totalFacturadoMes;
  final double totalCobradoMes;
  final double totalGastadoMes;
  final double margenEstimadoMes;
  final double saldoPendienteTotal;
  final int facturasPendientes;
  final int facturasVencidas;
  final int presupuestosAceptadosSinFacturar;
  final List<_MesEconomico> evolucionMensual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.request_quote_outlined,
                    color: AppColors.primary,
                    valor: formatCurrency(totalFacturadoMes),
                    label: 'Facturado este mes',
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                    valor: formatCurrency(totalCobradoMes),
                    label: 'Cobrado este mes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.receipt_outlined,
                    color: AppColors.accentStrong,
                    valor: formatCurrency(totalGastadoMes),
                    label: 'Gastado este mes',
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.trending_up_outlined,
                    color: margenEstimadoMes >= 0 ? AppColors.success : AppColors.error,
                    valor: formatCurrency(margenEstimadoMes),
                    label: 'Margen estimado del mes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.hourglass_bottom_outlined,
                    color: AppColors.warning,
                    valor: formatCurrency(saldoPendienteTotal),
                    label: '$facturasPendientes pendiente${facturasPendientes == 1 ? '' : 's'} de cobro',
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _MetricaEconomica(
                    icon: Icons.error_outline,
                    color: AppColors.error,
                    valor: '$facturasVencidas',
                    label: 'Factura${facturasVencidas == 1 ? '' : 's'} vencida${facturasVencidas == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
            if (presupuestosAceptadosSinFacturar > 0) ...[
              const Divider(height: AppSpace.lg),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      '$presupuestosAceptadosSinFacturar presupuesto'
                      '${presupuestosAceptadosSinFacturar == 1 ? '' : 's'} '
                      'aceptado${presupuestosAceptadosSinFacturar == 1 ? '' : 's'} '
                      'sin facturar todavía.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: AppSpace.lg),
            Text('Últimos 6 meses', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpace.sm),
            _MiniGraficoMensual(meses: evolucionMensual),
          ],
        ),
      ),
    );
  }
}

class _MetricaEconomica extends StatelessWidget {
  const _MetricaEconomica({
    required this.icon,
    required this.color,
    required this.valor,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String valor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barras en proporción al máximo de la ventana de 6 meses -- sin
/// paquete de gráficos (encargo: no añadir una dependencia grande para
/// esto). Si no hay ningún importe en toda la ventana, se omiten las
/// barras en vez de dibujar un gráfico vacío engañoso.
class _MiniGraficoMensual extends StatelessWidget {
  const _MiniGraficoMensual({required this.meses});

  final List<_MesEconomico> meses;

  @override
  Widget build(BuildContext context) {
    final maximo = meses.fold<double>(
      0,
      (m, e) => [m, e.facturado, e.cobrado].reduce((a, b) => a > b ? a : b),
    );
    if (maximo <= 0) {
      return Text(
        'Todavía no hay facturación registrada.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    const alturaMax = 56.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final m in meses)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 6,
                    height: 4 + alturaMax * (m.facturado / maximo),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 6,
                    height: 4 + alturaMax * (m.cobrado / maximo),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _mesesCorto[m.mes.month - 1],
                style: TextStyle(fontSize: 9.5, color: AppColors.inkFaint),
              ),
            ],
          ),
      ],
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
    for (final f in appData.facturas.facturas)
      if (f.fechaEmision != null)
        _EventoActividad(
          icono: Icons.receipt_long_outlined,
          texto: 'Factura emitida: ${f.numero ?? f.titulo}',
          fecha: f.fechaEmision!,
          esDemo: f.esDemo,
        ),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  return eventos.take(6).toList();
}

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({required this.texto, this.accion, this.onAccion});
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (accion != null && onAccion != null)
              TextButton(onPressed: onAccion, child: Text(accion!)),
          ],
        ),
      ),
    );
  }
}

class _FilaCitaHoy extends StatelessWidget {
  const _FilaCitaHoy({required this.appData, required this.cita});

  final AppData appData;
  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final cliente = cita.clienteId != null
        ? appData.clientes.byId(cita.clienteId!)
        : null;
    final trabajo = cita.trabajoId != null
        ? appData.trabajos.byId(cita.trabajoId!)
        : null;
    final subtitulo = [
      if (cliente != null) cliente.nombre,
      if (trabajo != null) trabajo.titulo,
    ].join(' · ');
    return ListTile(
      leading: Container(
        width: 44,
        alignment: Alignment.center,
        child: Text(
          formatTime(cita.fechaHora),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(cita.titulo, overflow: TextOverflow.ellipsis),
          ),
          if (cita.esDemo) ...[const SizedBox(width: 6), const DemoTag()],
        ],
      ),
      subtitle: subtitulo.isEmpty ? null : Text(subtitulo),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => mostrarFormularioCita(
        context,
        appData: appData,
        existente: cita,
      ),
    );
  }
}
