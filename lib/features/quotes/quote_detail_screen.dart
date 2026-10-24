// lib/features/quotes/quote_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/demo_tag.dart';
import '../../data/app_data.dart';
import '../../data/models/presupuesto.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_sheet.dart';
import 'quote_form_screen.dart';

Color _colorEstadoPresupuesto(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => AppColors.inkFaint,
  EstadoPresupuesto.enviado => AppColors.primary,
  EstadoPresupuesto.aceptado => AppColors.success,
  EstadoPresupuesto.rechazado => AppColors.error,
};

class QuoteDetailScreen extends StatelessWidget {
  const QuoteDetailScreen({
    required this.appData,
    required this.presupuestoId,
    super.key,
  });

  final AppData appData;
  final String presupuestoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appData.presupuestos,
        appData.clientes,
      ]),
      builder: (context, _) {
        final presupuesto = appData.presupuestos.byId(presupuestoId);
        if (presupuesto == null) {
          return const Scaffold(
            body: Center(child: Text('Este presupuesto ya no existe.')),
          );
        }
        final cliente = appData.clientes.byId(presupuesto.clienteId);
        final color = _colorEstadoPresupuesto(presupuesto.estado);
        final totales = presupuesto.totales;
        // Derivado desde el lado del trabajo (nunca se escribe en el
        // presupuesto -- ver TrabajoRepository.porPresupuesto): si ya
        // existe un trabajo para este presupuesto, se ofrece abrirlo en
        // vez de poder crear otro.
        final trabajosVinculados = appData.trabajos.porPresupuesto(
          presupuesto.id,
        );
        final trabajoVinculado = trabajosVinculados.isEmpty
            ? null
            : trabajosVinculados.first;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    presupuesto.titulo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (presupuesto.esDemo) ...[
                  const SizedBox(width: 8),
                  const DemoTag(),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuoteFormScreen(
                      appData: appData,
                      clienteIdFijo: presupuesto.clienteId,
                      trabajoIdFijo: presupuesto.trabajoId,
                      existente: presupuesto,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmar = await confirmarEliminar(
                    context,
                    titulo: '¿Eliminar este presupuesto?',
                  );
                  if (confirmar) {
                    await appData.presupuestos.delete(presupuestoId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(nombreEstadoPresupuesto(presupuesto.estado)),
                    backgroundColor: color.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    formatDate(presupuesto.creadoEl),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                cliente?.nombre ?? 'Cliente eliminado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.lg),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < presupuesto.conceptos.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        title: Text(presupuesto.conceptos[i].descripcion),
                        subtitle: Text(
                          '${_formatearCantidad(presupuesto.conceptos[i].cantidad)} '
                          '× ${formatCurrency(presupuesto.conceptos[i].precioUnitario)}',
                        ),
                        trailing: Text(
                          formatCurrency(presupuesto.conceptos[i].subtotal),
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
                      _FilaTotalDetalle('Subtotal', totales.subtotal),
                      _FilaTotalDetalle(
                        'IVA (${presupuesto.ivaPorcentaje.toStringAsFixed(0)}%)',
                        totales.iva,
                      ),
                      const Divider(height: AppSpace.lg),
                      _FilaTotalDetalle(
                        'Total',
                        totales.total,
                        destacado: true,
                      ),
                    ],
                  ),
                ),
              ),
              if (presupuesto.estado == EstadoPresupuesto.borrador ||
                  presupuesto.estado == EstadoPresupuesto.enviado) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  // Deliberadamente explícito: la app no manda nada por su
                  // cuenta, solo registra el estado que tú le indiques
                  // después de pasárselo al cliente (en persona, WhatsApp,
                  // email...).
                  presupuesto.estado == EstadoPresupuesto.borrador
                      ? 'Cuando se lo hayas pasado al cliente, regístralo aquí.'
                      : 'Registrado como enviado. Anota aquí su respuesta cuando la tengas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    if (presupuesto.estado == EstadoPresupuesto.borrador)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => appData.presupuestos.update(
                            presupuesto.copyWith(
                              estado: EstadoPresupuesto.enviado,
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_outlined, size: 18),
                          label: const Text('Marcar como enviado'),
                        ),
                      ),
                    if (presupuesto.estado == EstadoPresupuesto.enviado) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => appData.presupuestos.update(
                            presupuesto.copyWith(
                              estado: EstadoPresupuesto.rechazado,
                            ),
                          ),
                          child: const Text('Rechazado'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('¿Registrar como aceptado?'),
                                content: const Text(
                                  'Confirma que el cliente lo ha aceptado. '
                                  'Los conceptos y el importe no cambian, '
                                  'y no se envía ningún aviso al cliente.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Confirmar aceptación'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmar == true) {
                              await appData.presupuestos.update(
                                presupuesto.copyWith(
                                  estado: EstadoPresupuesto.aceptado,
                                ),
                              );
                            }
                          },
                          child: const Text('Aceptado'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (presupuesto.estado == EstadoPresupuesto.aceptado) ...[
                const SizedBox(height: AppSpace.lg),
                if (trabajoVinculado == null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => mostrarFormularioTrabajo(
                        context,
                        appData: appData,
                        clienteId: presupuesto.clienteId,
                        tituloInicial: presupuesto.titulo,
                        presupuestoIdFijo: presupuesto.id,
                      ),
                      icon: const Icon(Icons.build_outlined, size: 18),
                      label: const Text('Crear trabajo'),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.build_outlined,
                        color: AppColors.success,
                      ),
                      title: const Text('Ya tiene un trabajo creado'),
                      subtitle: Text(trabajoVinculado.titulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(
                            appData: appData,
                            trabajoId: trabajoVinculado.id,
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
  const _FilaTotalDetalle(this.label, this.valor, {this.destacado = false});

  final String label;
  final double valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.primary)
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
