// lib/features/clients/clients_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import 'client_detail_screen.dart';
import 'client_form_sheet.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostrarFormularioCliente(
          context,
          repo: widget.appData.clientes,
        ),
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: ListenableBuilder(
        listenable: widget.appData.clientes,
        builder: (context, _) {
          final todos = widget.appData.clientes.clientes;
          final filtrados = _busqueda.trim().isEmpty
              ? todos
              : todos
                    .where(
                      (c) => c.nombre.toLowerCase().contains(
                        _busqueda.toLowerCase(),
                      ),
                    )
                    .toList();
          if (todos.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'Todavía no tienes clientes',
              message: 'Da de alta tu primer cliente para empezar a '
                  'organizar sus trabajos y presupuestos.',
              actionLabel: 'Añadir cliente',
              onAction: () => mostrarFormularioCliente(
                context,
                repo: widget.appData.clientes,
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar cliente...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Sin resultados',
                        message: 'Ningún cliente coincide con la búsqueda.',
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
                          final c = filtrados[i];
                          return AppListTile(
                            icon: Icons.person_outline,
                            title: c.nombre,
                            esDemo: c.esDemo,
                            subtitle: c.telefono ?? c.email ?? 'Sin contacto',
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.inkFaint,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientDetailScreen(
                                  appData: widget.appData,
                                  clienteId: c.id,
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
