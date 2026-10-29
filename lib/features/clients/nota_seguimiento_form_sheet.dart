// lib/features/clients/nota_seguimiento_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/nota_seguimiento.dart';

/// [conSeguimientoInicial] abre el formulario con el interruptor de
/// seguimiento ya activado -- usado por la acción "Programar
/// seguimiento" de la ficha del cliente, que es el mismo formulario que
/// "Añadir nota" con un punto de partida distinto (ver nota de cabecera
/// en nota_seguimiento.dart sobre por qué es un único modelo).
Future<void> mostrarFormularioNota(
  BuildContext context, {
  required AppData appData,
  required String clienteId,
  NotaSeguimiento? existente,
  bool conSeguimientoInicial = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NotaFormSheet(
      appData: appData,
      clienteId: clienteId,
      existente: existente,
      conSeguimientoInicial: conSeguimientoInicial,
    ),
  );
}

class _NotaFormSheet extends StatefulWidget {
  const _NotaFormSheet({
    required this.appData,
    required this.clienteId,
    this.existente,
    this.conSeguimientoInicial = false,
  });

  final AppData appData;
  final String clienteId;
  final NotaSeguimiento? existente;
  final bool conSeguimientoInicial;

  @override
  State<_NotaFormSheet> createState() => _NotaFormSheetState();
}

class _NotaFormSheetState extends State<_NotaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _textoCtrl = TextEditingController(text: widget.existente?.texto ?? '');
  late TipoNota _tipo = widget.existente?.tipo ?? TipoNota.general;
  late String? _trabajoId = widget.existente?.trabajoId;
  late String? _presupuestoId = widget.existente?.presupuestoId;
  late bool _conSeguimiento =
      widget.existente?.tieneSeguimiento ?? widget.conSeguimientoInicial;
  late DateTime _fechaSeguimiento =
      widget.existente?.fechaSeguimiento ?? DateTime.now().add(const Duration(days: 1));
  bool _guardando = false;

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeguimiento,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha != null) setState(() => _fechaSeguimiento = fecha);
  }

  Future<void> _guardar() async {
    // Evita un doble toque en "Guardar" -- mismo criterio que en el
    // resto de formularios de la app.
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      if (widget.existente != null) {
        await widget.appData.notasSeguimiento.actualizar(
          widget.existente!.copyWith(
            texto: _textoCtrl.text.trim(),
            tipo: _tipo,
            trabajoId: _trabajoId,
            presupuestoId: _presupuestoId,
            borrarTrabajoId: _trabajoId == null,
            borrarPresupuestoId: _presupuestoId == null,
            fechaSeguimiento: _conSeguimiento ? _fechaSeguimiento : null,
            borrarSeguimiento: !_conSeguimiento,
            // Si ya tenía un estado de seguimiento y sigue programado,
            // se conserva -- solo se reinicia a "pendiente" (dentro del
            // repositorio) cuando antes no tenía seguimiento ninguno.
            estadoSeguimiento: _conSeguimiento ? widget.existente!.estadoSeguimiento : null,
          ),
        );
      } else {
        await widget.appData.notasSeguimiento.add(
          NotaSeguimiento(
            id: const Uuid().v4(),
            clienteId: widget.clienteId,
            texto: _textoCtrl.text.trim(),
            tipo: _tipo,
            creadoEl: DateTime.now(),
            trabajoId: _trabajoId,
            presupuestoId: _presupuestoId,
            fechaSeguimiento: _conSeguimiento ? _fechaSeguimiento : null,
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
    final trabajosCliente = widget.appData.trabajos.porCliente(widget.clienteId);
    final presupuestosCliente = widget.appData.presupuestos.porCliente(widget.clienteId);
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
                  editando ? 'Editar nota' : 'Nueva nota',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                DropdownButtonFormField<TipoNota>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TipoNota.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(nombreTipoNota(t))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _tipo = v);
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _textoCtrl,
                  decoration: const InputDecoration(labelText: 'Nota *'),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 5,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                if (trabajosCliente.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: _trabajoId,
                    decoration: const InputDecoration(labelText: 'Trabajo relacionado (opcional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguno')),
                      for (final t in trabajosCliente)
                        DropdownMenuItem(value: t.id, child: Text(t.titulo)),
                    ],
                    onChanged: (v) => setState(() => _trabajoId = v),
                  ),
                ],
                if (presupuestosCliente.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: _presupuestoId,
                    decoration: const InputDecoration(
                      labelText: 'Presupuesto relacionado (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguno')),
                      for (final p in presupuestosCliente)
                        DropdownMenuItem(value: p.id, child: Text(p.titulo)),
                    ],
                    onChanged: (v) => setState(() => _presupuestoId = v),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Programar seguimiento'),
                  subtitle: const Text('Marca una fecha para volver a contactar'),
                  value: _conSeguimiento,
                  onChanged: (v) => setState(() => _conSeguimiento = v),
                ),
                if (_conSeguimiento) ...[
                  const SizedBox(height: AppSpace.sm),
                  OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(formatDate(_fechaSeguimiento)),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(editando ? 'Guardar cambios' : 'Guardar nota'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
