// lib/features/expenses/expenses_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/gasto.dart';
import 'expense_form_sheet.dart';

enum _Periodo { todos, esteMes }

IconData _iconoCategoria(CategoriaGasto c) => switch (c) {
  CategoriaGasto.materiales => Icons.construction_outlined,
  CategoriaGasto.desplazamiento => Icons.directions_car_outlined,
  CategoriaGasto.herramientas => Icons.handyman_outlined,
  CategoriaGasto.subcontratacion => Icons.groups_outlined,
  CategoriaGasto.suministros => Icons.bolt_outlined,
  CategoriaGasto.otros => Icons.receipt_outlined,
};

bool _enEstePeriodo(Gasto g, _Periodo periodo) {
  if (periodo == _Periodo.todos) return true;
  final ahora = DateTime.now();
  return g.fecha.year == ahora.year && g.fecha.month == ahora.month;
}

Future<void> _anularGasto(BuildContext context, AppData appData, Gasto gasto) async {
  final motivoCtrl = TextEditingController();
  final motivo = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Anular gasto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('El gasto se conserva, pero deja de contar en los totales.'),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: motivoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo *'),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, motivoCtrl.text),
          child: const Text('Anular'),
        ),
      ],
    ),
  );
  if (motivo == null || motivo.trim().isEmpty) return;
  try {
    await appData.gastos.anular(gasto.id, motivo);
  } on StateError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  _Periodo _periodo = _Periodo.esteMes;
  CategoriaGasto? _categoria;
  String? _trabajoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostrarFormularioGasto(context, appData: widget.appData),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.appData.gastos, widget.appData.trabajos]),
        builder: (context, _) {
          final todos = widget.appData.gastos.gastos;
          if (todos.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_outlined,
              title: 'Todavía no hay gastos',
              message: 'Registra materiales, desplazamientos u otros gastos del negocio.',
              actionLabel: 'Nuevo gasto',
              onAction: () => mostrarFormularioGasto(context, appData: widget.appData),
            );
          }

          final filtrados = todos.where((g) {
            if (!_enEstePeriodo(g, _periodo)) return false;
            if (_categoria != null && g.categoria != _categoria) return false;
            if (_trabajoId != null && g.trabajoId != _trabajoId) return false;
            return true;
          }).toList();

          // Solo los activos cuentan en el total -- un gasto anulado
          // se sigue viendo en la lista (para no esconder el rastro),
          // pero no en esta cifra (encargo, sección 1).
          final total = filtrados
              .where((g) => g.estado == EstadoGasto.activo)
              .fold<double>(0, (acc, g) => acc + g.importe);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _periodo == _Periodo.esteMes ? 'Total este mes' : 'Total del filtro',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        formatCurrency(total),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Este mes'),
                      selected: _periodo == _Periodo.esteMes,
                      onSelected: (_) => setState(() => _periodo = _Periodo.esteMes),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _periodo == _Periodo.todos,
                      onSelected: (_) => setState(() => _periodo = _Periodo.todos),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  children: [
                    const SizedBox(width: AppSpace.sm),
                    ChoiceChip(
                      label: const Text('Todas las categorías'),
                      selected: _categoria == null,
                      onSelected: (_) => setState(() => _categoria = null),
                    ),
                    for (final c in CategoriaGasto.values) ...[
                      const SizedBox(width: AppSpace.sm),
                      ChoiceChip(
                        label: Text(nombreCategoriaGasto(c)),
                        selected: _categoria == c,
                        onSelected: (_) => setState(() => _categoria = c),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.appData.trabajos.trabajos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.sm,
                    AppSpace.md,
                    AppSpace.sm,
                  ),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _trabajoId,
                    decoration: const InputDecoration(labelText: 'Trabajo', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos los trabajos')),
                      for (final t in widget.appData.trabajos.trabajos)
                        DropdownMenuItem(value: t.id, child: Text(t.titulo)),
                    ],
                    onChanged: (v) => setState(() => _trabajoId = v),
                  ),
                ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_list_off,
                        title: 'Sin resultados',
                        message: 'Prueba a cambiar los filtros de arriba.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) => const Divider(indent: 68, height: 1),
                        itemBuilder: (context, i) {
                          final g = filtrados[i];
                          final trabajo = g.trabajoId != null
                              ? widget.appData.trabajos.byId(g.trabajoId!)
                              : null;
                          final anulado = g.estado == EstadoGasto.anulado;
                          return AppListTile(
                            icon: _iconoCategoria(g.categoria),
                            iconColor: anulado ? AppColors.inkFaint : AppColors.primary,
                            esDemo: g.esDemo,
                            onTap: anulado
                                ? null
                                : () => mostrarFormularioGasto(
                                    context,
                                    appData: widget.appData,
                                    existente: g,
                                  ),
                            title: g.descripcion,
                            subtitle:
                                '${formatDate(g.fecha)} · ${nombreCategoriaGasto(g.categoria)}'
                                '${trabajo != null ? ' · ${trabajo.titulo}' : ''}'
                                '${anulado ? ' · Anulado' : ''}',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrency(g.importe),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: anulado ? AppColors.inkFaint : null,
                                    decoration: anulado ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (!anulado)
                                  PopupMenuButton<String>(
                                    onSelected: (accion) {
                                      if (accion == 'editar') {
                                        mostrarFormularioGasto(
                                          context,
                                          appData: widget.appData,
                                          existente: g,
                                        );
                                      } else if (accion == 'anular') {
                                        _anularGasto(context, widget.appData, g);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                                      PopupMenuItem(value: 'anular', child: Text('Anular')),
                                    ],
                                  ),
                              ],
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
