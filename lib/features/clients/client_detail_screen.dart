// lib/features/clients/client_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/quick_action_button.dart';
import '../../core/widgets/section_header.dart';
import '../../data/app_data.dart';
import '../../data/models/cita.dart';
import '../../data/models/factura.dart';
import '../../data/models/nota_seguimiento.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/trabajo.dart';
import '../calendar/appointment_form_sheet.dart';
import '../invoices/invoice_detail_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_sheet.dart';
import '../quotes/quote_detail_screen.dart';
import '../quotes/quote_form_screen.dart';
import 'client_form_sheet.dart';
import 'nota_seguimiento_form_sheet.dart';

IconData _iconoTipoNota(TipoNota t) => switch (t) {
  TipoNota.general => Icons.sticky_note_2_outlined,
  TipoNota.llamada => Icons.call_outlined,
  TipoNota.visita => Icons.place_outlined,
  TipoNota.seguimientoPresupuesto => Icons.request_quote_outlined,
  TipoNota.otro => Icons.label_outline,
};

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({
    required this.appData,
    required this.clienteId,
    super.key,
  });

  final AppData appData;
  final String clienteId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appData.clientes,
        appData.trabajos,
        appData.presupuestos,
        appData.facturas,
        appData.citas,
        appData.notasSeguimiento,
      ]),
      builder: (context, _) {
        final cliente = appData.clientes.byId(clienteId);
        if (cliente == null) {
          return const Scaffold(
            body: Center(child: Text('Este cliente ya no existe.')),
          );
        }
        final trabajos = appData.trabajos.porCliente(clienteId);
        final presupuestos = appData.presupuestos.porCliente(clienteId);
        final facturas = appData.facturas.porCliente(clienteId);
        final citas = appData.citas.porCliente(clienteId);
        final notas = appData.notasSeguimiento.porCliente(clienteId);

        // Historial económico (mismo criterio que la rentabilidad de un
        // trabajo, ver job_detail_screen.dart): solo facturas EMITIDAS
        // cuentan como facturación real -- nunca un borrador (importe
        // todavía puede cambiar) ni una anulada (sin efecto fiscal).
        // f.importeFacturacion, no f.totales.total: una rectificativa
        // "importe resultante" ya declara la diferencia neta: sumar su
        // total completo junto al de la original contaría la operación
        // dos veces (ver Factura.importeFacturacion).
        final facturasVigentes = facturas.where((f) => f.estado == EstadoFactura.emitida).toList();
        final totalFacturado = facturasVigentes.fold<double>(
          0,
          (acc, f) => acc + f.importeFacturacion,
        );
        // Una rectificativa nunca tiene pagos propios (ver
        // FacturaRepository.registrarPago()), así que sumar sus pagos
        // (siempre vacíos) junto a los de la original no duplica nada.
        final totalCobrado = facturasVigentes
            .expand((f) => f.pagos)
            .fold<double>(0, (acc, p) => acc + p.importe);
        final saldoPendiente = facturasVigentes.fold<double>(
          0,
          (acc, f) => acc + f.saldoPendiente,
        );
        final hayHistorialEconomico = facturasVigentes.isNotEmpty;

        // Última actividad: la fecha más reciente entre todo lo que
        // relaciona a este cliente. Null (y no se muestra nada) si no
        // hay ningún registro todavía -- nunca se inventa una fecha.
        DateTime? ultimaActividad;
        void considerarFecha(DateTime? fecha) {
          if (fecha == null) return;
          if (ultimaActividad == null || fecha.isAfter(ultimaActividad!)) {
            ultimaActividad = fecha;
          }
        }

        for (final t in trabajos) {
          considerarFecha(t.creadoEl);
        }
        for (final p in presupuestos) {
          considerarFecha(p.creadoEl);
        }
        for (final f in facturas) {
          considerarFecha(f.creadaEl);
        }
        for (final n in notas) {
          considerarFecha(n.creadoEl);
        }

        // Próxima cita: la más próxima en el futuro y no completada.
        // Null si no hay ninguna -- no se muestra una fecha inventada.
        final citasFuturas = citas.where((c) => !c.completada && c.fechaHora.isAfter(DateTime.now())).toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        final proximaCita = citasFuturas.isEmpty ? null : citasFuturas.first;

        // Seguimientos pendientes de este cliente, agrupados. Un
        // seguimiento ya marcado realizado/cancelado nunca se clasifica
        // como atrasado/hoy/futuro (ver NotaSeguimiento.esSeguimiento*).
        final seguimientosAtrasados = notas.where((n) => n.esSeguimientoAtrasado()).toList();
        final seguimientosHoy = notas.where((n) => n.esSeguimientoHoy()).toList();
        final seguimientosFuturos = notas.where((n) => n.esSeguimientoFuturo()).toList()
          ..sort((a, b) => a.fechaSeguimiento!.compareTo(b.fechaSeguimiento!));

        // Mismo "ahora" para los dos grupos de abajo, para que sean
        // exhaustivos y mutuamente excluyentes incluso si el reloj
        // avanza entre una comprobación y la otra.
        final ahoraParaCitas = DateTime.now();
        // Citas del cliente (auditoría AUD-11-02), agrupadas en dos
        // bloques -- no hay ningún estado "cancelada" en el modelo
        // [Cita] (solo [completada], un simple sí/no -- ver cita.dart),
        // así que no se inventa uno nuevo aquí: una cita ya completada
        // se trata siempre como "Anterior" sin importar su fecha (ya
        // está resuelta), y una cita pasada que nunca se marcó
        // completada también cae en "Anteriores" -- es la aproximación
        // más honesta a "pasada o cancelada" que el modelo permite
        // expresar hoy sin ampliarlo.
        final citasProximas = citas.where((c) => !c.completada && c.fechaHora.isAfter(ahoraParaCitas)).toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        final citasAnteriores = citas.where((c) => c.completada || !c.fechaHora.isAfter(ahoraParaCitas)).toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(cliente.nombre, overflow: TextOverflow.ellipsis),
                ),
                if (cliente.esDemo) ...[
                  const SizedBox(width: 8),
                  const DemoTag(),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => mostrarFormularioCliente(
                  context,
                  repo: appData.clientes,
                  existente: cliente,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmar = await confirmarEliminar(
                    context,
                    titulo: '¿Eliminar este cliente?',
                    mensaje:
                        'Sus trabajos, presupuestos, facturas y citas no se '
                        'eliminan, pero quedarán sin cliente asociado. Sus '
                        'notas de seguimiento sí se eliminarán, junto con el '
                        'cliente.',
                  );
                  if (confirmar) {
                    await appData.eliminarCliente(clienteId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cliente.telefono != null)
                        _FilaContacto(icon: Icons.call_outlined, texto: cliente.telefono!),
                      if (cliente.email != null)
                        _FilaContacto(icon: Icons.mail_outline, texto: cliente.email!),
                      if (cliente.direccion != null)
                        _FilaContacto(icon: Icons.place_outlined, texto: cliente.direccion!),
                      if (ultimaActividad != null)
                        _FilaContacto(
                          icon: Icons.history,
                          texto: 'Última actividad: ${formatDate(ultimaActividad!)}',
                        ),
                      if (proximaCita != null)
                        _FilaContacto(
                          icon: Icons.event_outlined,
                          texto: 'Próxima cita: ${formatDateTime(proximaCita.fechaHora)}',
                        ),
                      if (cliente.notas != null) ...[
                        const Divider(height: AppSpace.lg),
                        Text(cliente.notas!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      if (cliente.telefono == null &&
                          cliente.email == null &&
                          cliente.direccion == null &&
                          cliente.notas == null &&
                          ultimaActividad == null &&
                          proximaCita == null)
                        Text(
                          'Sin datos de contacto guardados todavía.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  QuickActionButton(
                    icon: Icons.build_outlined,
                    label: 'Trabajo',
                    onTap: () => mostrarFormularioTrabajo(
                      context,
                      appData: appData,
                      clienteId: clienteId,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  QuickActionButton(
                    icon: Icons.request_quote_outlined,
                    label: 'Presupuesto',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuoteFormScreen(appData: appData, clienteIdFijo: clienteId),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  QuickActionButton(
                    icon: Icons.note_add_outlined,
                    label: 'Nota',
                    onTap: () => mostrarFormularioNota(context, appData: appData, clienteId: clienteId),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  QuickActionButton(
                    icon: Icons.notifications_active_outlined,
                    label: 'Seguimiento',
                    onTap: () => mostrarFormularioNota(
                      context,
                      appData: appData,
                      clienteId: clienteId,
                      conSeguimientoInicial: true,
                    ),
                  ),
                ],
              ),
              if (hayHistorialEconomico) ...[
                const SizedBox(height: AppSpace.lg),
                Text('Historial económico', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpace.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      children: [
                        _FilaResumen('Facturado', totalFacturado),
                        _FilaResumen('Cobrado', totalCobrado),
                        _FilaResumen(
                          'Pendiente de cobro',
                          saldoPendiente,
                          destacado: saldoPendiente > 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (seguimientosAtrasados.isNotEmpty ||
                  seguimientosHoy.isNotEmpty ||
                  seguimientosFuturos.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Text('Seguimientos pendientes', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpace.sm),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final n in [...seguimientosAtrasados, ...seguimientosHoy, ...seguimientosFuturos])
                        _FilaSeguimiento(
                          nota: n,
                          atrasado: n.esSeguimientoAtrasado(),
                          hoy: n.esSeguimientoHoy(),
                          onRealizado: () => appData.notasSeguimiento.marcarSeguimientoRealizado(n.id),
                          onCancelado: () => appData.notasSeguimiento.marcarSeguimientoCancelado(n.id),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Citas'),
              const SizedBox(height: AppSpace.sm),
              if (citasProximas.isEmpty && citasAnteriores.isEmpty)
                const _TarjetaVacia('Sin citas todavía.')
              else ...[
                if (citasProximas.isNotEmpty) ...[
                  // Etiqueta de grupo solo cuando hay los dos bloques --
                  // con uno solo, el título "Citas" de arriba ya basta,
                  // repetirlo sería ruido.
                  if (citasAnteriores.isNotEmpty) ...[
                    Text(
                      'Próximas',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: AppSpace.xs),
                  ],
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < citasProximas.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _FilaCita(
                            cita: citasProximas[i],
                            onTap: () => mostrarFormularioCita(
                              context,
                              appData: appData,
                              existente: citasProximas[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (citasProximas.isNotEmpty && citasAnteriores.isNotEmpty)
                  const SizedBox(height: AppSpace.md),
                if (citasAnteriores.isNotEmpty) ...[
                  if (citasProximas.isNotEmpty) ...[
                    Text(
                      'Anteriores',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: AppSpace.xs),
                  ],
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < citasAnteriores.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _FilaCita(
                            cita: citasAnteriores[i],
                            onTap: () => mostrarFormularioCita(
                              context,
                              appData: appData,
                              existente: citasAnteriores[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Trabajos'),
              const SizedBox(height: AppSpace.sm),
              if (trabajos.isEmpty)
                const _TarjetaVacia('Sin trabajos todavía.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < trabajos.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          title: Text(trabajos[i].titulo),
                          subtitle: Text(nombreEstadoTrabajo(trabajos[i].estado)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(appData: appData, trabajoId: trabajos[i].id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Presupuestos'),
              const SizedBox(height: AppSpace.sm),
              if (presupuestos.isEmpty)
                const _TarjetaVacia('Sin presupuestos todavía.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < presupuestos.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          title: Text(presupuestos[i].titulo),
                          subtitle: Text(
                            '${nombreEstadoPresupuesto(presupuestos[i].estado)} · '
                            '${formatCurrency(presupuestos[i].totales.total)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuoteDetailScreen(appData: appData, presupuestoId: presupuestos[i].id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Facturas'),
              const SizedBox(height: AppSpace.sm),
              if (facturas.isEmpty)
                const _TarjetaVacia('Sin facturas todavía.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < facturas.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ListTile(
                          title: Text(facturas[i].numero ?? facturas[i].titulo),
                          subtitle: Text(
                            '${etiquetaFactura(facturas[i])} · '
                            '${formatCurrency(facturas[i].totales.total)}'
                            '${facturas[i].saldoPendiente > 0 ? ' · Pendiente ${formatCurrency(facturas[i].saldoPendiente)}' : ''}',
                          ),
                          subtitleTextStyle: TextStyle(color: colorEstadoFactura(facturas[i])),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvoiceDetailScreen(appData: appData, facturaId: facturas[i].id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              SectionHeader(
                title: 'Notas',
                actionLabel: 'Añadir',
                onAction: () => mostrarFormularioNota(context, appData: appData, clienteId: clienteId),
              ),
              const SizedBox(height: AppSpace.sm),
              if (notas.isEmpty)
                const _TarjetaVacia('Sin notas todavía.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < notas.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _FilaNota(
                          nota: notas[i],
                          onTap: () => mostrarFormularioNota(
                            context,
                            appData: appData,
                            clienteId: clienteId,
                            existente: notas[i],
                          ),
                          onEliminar: () async {
                            final confirmar = await confirmarEliminar(
                              context,
                              titulo: '¿Eliminar esta nota?',
                            );
                            if (confirmar) {
                              await appData.notasSeguimiento.eliminar(notas[i].id);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              if (trabajos.isEmpty &&
                  presupuestos.isEmpty &&
                  facturas.isEmpty &&
                  notas.isEmpty &&
                  citas.isEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                const EmptyState(
                  icon: Icons.work_outline,
                  title: 'Sin actividad todavía',
                  message: 'Crea un trabajo o añade una nota para empezar a hacer seguimiento.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilaContacto extends StatelessWidget {
  const _FilaContacto({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.inkMuted),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// Fila de la tarjeta de historial económico -- mismo patrón visual que
/// _FilaRentabilidad de job_detail_screen.dart.
class _FilaResumen extends StatelessWidget {
  const _FilaResumen(this.label, this.valor, {this.destacado = false});

  final String label;
  final double valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w700,
          )
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

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia(this.texto);

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

class _FilaSeguimiento extends StatelessWidget {
  const _FilaSeguimiento({
    required this.nota,
    required this.atrasado,
    required this.hoy,
    required this.onRealizado,
    required this.onCancelado,
  });

  final NotaSeguimiento nota;
  final bool atrasado;
  final bool hoy;
  final VoidCallback onRealizado;
  final VoidCallback onCancelado;

  @override
  Widget build(BuildContext context) {
    final color = atrasado ? AppColors.error : (hoy ? AppColors.warning : AppColors.primary);
    final etiqueta = atrasado ? 'Atrasado' : (hoy ? 'Hoy' : formatDate(nota.fechaSeguimiento!));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 18, color: color),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(nota.texto, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Marcar como realizado',
            icon: const Icon(Icons.check_circle_outline, size: 20),
            onPressed: onRealizado,
          ),
          IconButton(
            tooltip: 'Cancelar seguimiento',
            icon: const Icon(Icons.cancel_outlined, size: 20),
            onPressed: onCancelado,
          ),
        ],
      ),
    );
  }
}

class _FilaNota extends StatelessWidget {
  const _FilaNota({required this.nota, required this.onTap, required this.onEliminar});

  final NotaSeguimiento nota;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_iconoTipoNota(nota.tipo), color: AppColors.primary),
      title: Text(nota.texto, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${nombreTipoNota(nota.tipo)} · ${formatDate(nota.creadoEl)}'
        '${nota.tieneSeguimiento ? ' · Seguimiento ${formatDate(nota.fechaSeguimiento!)} '
              '(${nombreEstadoSeguimiento(nota.estadoSeguimiento!)})' : ''}',
      ),
      onTap: onTap,
      trailing: IconButton(
        tooltip: 'Eliminar nota',
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onEliminar,
      ),
    );
  }
}

/// Fila de la sección "Citas" -- mismo lenguaje visual que la lista de
/// calendar_screen.dart (tachado + icono relleno/hueco según
/// [Cita.completada]), para no inventar un estilo nuevo solo para esta
/// pantalla. Tocar abre el mismo formulario de edición que usa la
/// agenda (mostrarFormularioCita) -- no hay un flujo de edición propio
/// de esta ficha.
class _FilaCita extends StatelessWidget {
  const _FilaCita({required this.cita, required this.onTap});

  final Cita cita;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        cita.completada ? Icons.check_circle : Icons.check_circle_outline,
        color: cita.completada ? AppColors.success : AppColors.inkFaint,
      ),
      title: Text(
        cita.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: cita.completada ? TextDecoration.lineThrough : null,
          color: cita.completada ? AppColors.inkFaint : null,
        ),
      ),
      subtitle: Text(formatDateTime(cita.fechaHora)),
      onTap: onTap,
    );
  }
}
