// lib/features/expenses/expense_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/gasto.dart';

Future<void> mostrarFormularioGasto(
  BuildContext context, {
  required AppData appData,
  String? trabajoIdFijo,
  Gasto? existente,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExpenseFormSheet(
      appData: appData,
      trabajoIdFijo: trabajoIdFijo,
      existente: existente,
    ),
  );
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.appData,
    this.trabajoIdFijo,
    this.existente,
  });

  final AppData appData;
  final String? trabajoIdFijo;
  final Gasto? existente;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _descripcionCtrl = TextEditingController(
    text: widget.existente?.descripcion ?? '',
  );
  late final _importeCtrl = TextEditingController(
    text: widget.existente != null ? widget.existente!.importe.toStringAsFixed(2) : '',
  );
  late final _proveedorCtrl = TextEditingController(
    text: widget.existente?.proveedor ?? '',
  );
  late final _notasCtrl = TextEditingController(
    text: widget.existente?.notas ?? '',
  );
  late DateTime _fecha = widget.existente?.fecha ?? DateTime.now();
  late CategoriaGasto _categoria = widget.existente?.categoria ?? CategoriaGasto.materiales;
  late String? _trabajoId = widget.existente?.trabajoId ?? widget.trabajoIdFijo;
  bool _guardando = false;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _importeCtrl.dispose();
    _proveedorCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    // Evita un doble toque en "Guardar" -- mismo motivo que en
    // invoice_rectification_screen.dart: sin esto, dos toques rápidos
    // podrían crear dos gastos idénticos (encargo, sección 2).
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      final importe = double.parse(_importeCtrl.text.replaceAll(',', '.'));
      final proveedor = _proveedorCtrl.text.trim().isEmpty
          ? null
          : _proveedorCtrl.text.trim();
      final notas = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
      if (widget.existente != null) {
        await widget.appData.gastos.update(
          widget.existente!.copyWith(
            descripcion: _descripcionCtrl.text.trim(),
            importe: importe,
            fecha: _fecha,
            categoria: _categoria,
            proveedor: proveedor,
            notas: notas,
            trabajoId: _trabajoId,
          ),
        );
      } else {
        await widget.appData.gastos.add(
          Gasto(
            id: const Uuid().v4(),
            descripcion: _descripcionCtrl.text.trim(),
            importe: importe,
            fecha: _fecha,
            categoria: _categoria,
            proveedor: proveedor,
            notas: notas,
            trabajoId: _trabajoId,
            creadoEl: DateTime.now(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  editando ? 'Editar gasto' : 'Nuevo gasto',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción *'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _importeCtrl,
                  decoration: const InputDecoration(labelText: 'Importe (€) *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final valor = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (valor == null) return 'Importe no válido';
                    if (valor <= 0) return 'Debe ser mayor que cero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(formatDate(_fecha)),
                ),
                const SizedBox(height: AppSpace.sm),
                DropdownButtonFormField<CategoriaGasto>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: CategoriaGasto.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(nombreCategoriaGasto(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _categoria = v);
                  },
                ),
                if (widget.trabajoIdFijo == null) ...[
                  const SizedBox(height: AppSpace.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: _trabajoId,
                    decoration: const InputDecoration(labelText: 'Trabajo asociado (opcional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin trabajo asociado')),
                      for (final t in widget.appData.trabajos.trabajos)
                        DropdownMenuItem(value: t.id, child: Text(t.titulo)),
                    ],
                    onChanged: (v) => setState(() => _trabajoId = v),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _proveedorCtrl,
                  decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpace.lg),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(editando ? 'Guardar cambios' : 'Registrar gasto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
