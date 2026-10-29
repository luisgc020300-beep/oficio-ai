// lib/features/clients/clients_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/cliente.dart';
import '../../data/models/factura.dart';
import '../../data/models/nota_seguimiento.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/trabajo.dart';
import 'client_detail_screen.dart';
import 'client_form_sheet.dart';

enum _FiltroCliente {
  todos,
  trabajosActivos,
  presupuestosPendientes,
  facturasPendientes,
  seguimientoProgramado,
}

String _nombreFiltroCliente(_FiltroCliente f) => switch (f) {
  _FiltroCliente.todos => 'Todos',
  _FiltroCliente.trabajosActivos => 'Trabajos activos',
  _FiltroCliente.presupuestosPendientes => 'Presupuestos pendientes',
  _FiltroCliente.facturasPendientes => 'Con saldo pendiente',
  _FiltroCliente.seguimientoProgramado => 'Seguimiento programado',
};

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  String _busqueda = '';
  _FiltroCliente _filtro = _FiltroCliente.todos;

  bool _coincideBusqueda(Cliente c, String busqueda) {
    if (busqueda.isEmpty) return true;
    final q = busqueda.toLowerCase();
    return c.nombre.toLowerCase().contains(q) ||
        (c.telefono?.toLowerCase().contains(q) ?? false) ||
        (c.email?.toLowerCase().contains(q) ?? false);
  }

  bool _coincideFiltro(Cliente c, _FiltroCliente filtro) {
    switch (filtro) {
      case _FiltroCliente.todos:
        return true;
      case _FiltroCliente.trabajosActivos:
        return widget.appData.trabajos
            .porCliente(c.id)
            .any((t) => t.estado == EstadoTrabajo.pendiente || t.estado == EstadoTrabajo.enCurso);
      case _FiltroCliente.presupuestosPendientes:
        return widget.appData.presupuestos
            .porCliente(c.id)
            .any((p) => p.estado == EstadoPresupuesto.enviado);
      case _FiltroCliente.facturasPendientes:
        // Saldo pendiente real, no "tiene alguna factura" -- no se
        // etiqueta a nadie de moroso: solo que hay un importe por
        // cobrar todavía, sin presumir que esté vencido.
        return widget.appData.facturas
            .porCliente(c.id)
            .any((f) => f.estado == EstadoFactura.emitida && f.saldoPendiente > 0);
      case _FiltroCliente.seguimientoProgramado:
        return widget.appData.notasSeguimiento
            .porCliente(c.id)
            .any((n) => n.estadoSeguimiento == EstadoSeguimiento.pendiente);
    }
  }

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
        listenable: Listenable.merge([
          widget.appData.clientes,
          widget.appData.trabajos,
          widget.appData.presupuestos,
          widget.appData.facturas,
          widget.appData.notasSeguimiento,
        ]),
        builder: (context, _) {
          final todos = widget.appData.clientes.clientes;
          final filtrados = todos
              .where((c) => _coincideBusqueda(c, _busqueda.trim()))
              .where((c) => _coincideFiltro(c, _filtro))
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
                    hintText: 'Buscar por nombre, teléfono o correo...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  key: const Key('filtroClienteChips'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  children: [
                    for (final f in _FiltroCliente.values) ...[
                      ChoiceChip(
                        label: Text(_nombreFiltroCliente(f)),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Expanded(
                child: filtrados.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'Sin resultados',
                        message: _filtro == _FiltroCliente.todos
                            ? 'Ningún cliente coincide con la búsqueda.'
                            : 'Ningún cliente coincide con "${_nombreFiltroCliente(_filtro)}".',
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
                            trailing: Icon(
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
