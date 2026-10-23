// lib/features/quotes/quotes_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/presupuesto.dart';
import 'assisted_quote_screen.dart';
import 'quote_detail_screen.dart';
import 'quote_form_screen.dart';

Color _colorEstado(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => AppColors.inkFaint,
  EstadoPresupuesto.enviado => AppColors.primary,
  EstadoPresupuesto.aceptado => AppColors.success,
  EstadoPresupuesto.rechazado => AppColors.error,
};

class QuotesListScreen extends StatelessWidget {
  const QuotesListScreen({required this.appData, super.key});

  final AppData appData;

  void _nuevo(BuildContext context) {
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

  void _nuevoAsistido(BuildContext context) {
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
      MaterialPageRoute(
        builder: (_) => AssistedQuoteScreen(appData: appData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _nuevo(context),
        tooltip: 'Nuevo presupuesto (manual)',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          appData.presupuestos,
          appData.clientes,
        ]),
        builder: (context, _) {
          final todos = appData.presupuestos.presupuestos;
          if (todos.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'Todavía no hay presupuestos',
                    message: 'Crea el primero para un cliente ya dado de alta.',
                    actionLabel: 'Nuevo presupuesto',
                    onAction: () => _nuevo(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    0,
                    AppSpace.md,
                    AppSpace.lg,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _nuevoAsistido(context),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: const Text('O crear uno con ayuda'),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.lg,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm,
                  0,
                  AppSpace.sm,
                  AppSpace.sm,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _nuevoAsistido(context),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Crear presupuesto con ayuda'),
                ),
              ),
              for (var i = 0; i < todos.length; i++) ...[
                if (i > 0) const Divider(indent: 68, height: 1),
                AppListTile(
                  icon: Icons.request_quote_outlined,
                  iconColor: _colorEstado(todos[i].estado),
                  title: todos[i].titulo,
                  esDemo: todos[i].esDemo,
                  subtitle:
                      '${appData.clientes.byId(todos[i].clienteId)?.nombre ?? 'Sin cliente'} · '
                      '${nombreEstadoPresupuesto(todos[i].estado)}',
                  trailing: Text(
                    formatCurrency(todos[i].totales.total),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuoteDetailScreen(
                        appData: appData,
                        presupuestoId: todos[i].id,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
