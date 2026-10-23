// lib/features/clients/client_detail_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/app_data.dart';
import '../../data/models/trabajo.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_sheet.dart';
import '../quotes/quote_detail_screen.dart';
import 'client_form_sheet.dart';

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
                        'Sus trabajos y presupuestos no se eliminan, pero '
                        'quedarán sin cliente asociado.',
                  );
                  if (confirmar) {
                    await appData.clientes.delete(clienteId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => mostrarFormularioTrabajo(
              context,
              appData: appData,
              clienteId: clienteId,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Trabajo'),
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
                        _FilaContacto(
                          icon: Icons.call_outlined,
                          texto: cliente.telefono!,
                        ),
                      if (cliente.email != null)
                        _FilaContacto(
                          icon: Icons.mail_outline,
                          texto: cliente.email!,
                        ),
                      if (cliente.direccion != null)
                        _FilaContacto(
                          icon: Icons.place_outlined,
                          texto: cliente.direccion!,
                        ),
                      if (cliente.notas != null) ...[
                        const Divider(height: AppSpace.lg),
                        Text(
                          cliente.notas!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (cliente.telefono == null &&
                          cliente.email == null &&
                          cliente.direccion == null &&
                          cliente.notas == null)
                        Text(
                          'Sin datos de contacto guardados todavía.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              const SectionHeader(title: 'Trabajos'),
              const SizedBox(height: AppSpace.sm),
              if (trabajos.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      'Sin trabajos todavía.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
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
                              builder: (_) => JobDetailScreen(
                                appData: appData,
                                trabajoId: trabajos[i].id,
                              ),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      'Sin presupuestos todavía.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
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
                            formatCurrency(presupuestos[i].totales.total),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuoteDetailScreen(
                                appData: appData,
                                presupuestoId: presupuestos[i].id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (trabajos.isEmpty && presupuestos.isEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                const EmptyState(
                  icon: Icons.work_outline,
                  title: 'Sin actividad todavía',
                  message:
                      'Crea el primer trabajo de este cliente con el botón '
                      'de abajo.',
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
