// lib/features/calendar/appointment_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../data/app_data.dart';
import '../../data/models/cita.dart';
import '../jobs/job_detail_screen.dart';

Future<void> mostrarFormularioCita(
  BuildContext context, {
  required AppData appData,
  DateTime? diaInicial,
  Cita? existente,
  String? clienteIdFijo,
  String? trabajoIdFijo,
  String? tituloInicial,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppointmentFormSheet(
      appData: appData,
      diaInicial: diaInicial,
      existente: existente,
      clienteIdFijo: clienteIdFijo,
      trabajoIdFijo: trabajoIdFijo,
      tituloInicial: tituloInicial,
    ),
  );
}

class _AppointmentFormSheet extends StatefulWidget {
  const _AppointmentFormSheet({
    required this.appData,
    this.diaInicial,
    this.existente,
    this.clienteIdFijo,
    this.trabajoIdFijo,
    this.tituloInicial,
  });

  final AppData appData;
  final DateTime? diaInicial;
  final Cita? existente;

  /// Precargados al programar una visita desde la ficha de un trabajo
  /// (ver job_detail_screen.dart) -- ignorados si [existente] no es null.
  final String? clienteIdFijo;
  final String? trabajoIdFijo;
  final String? tituloInicial;

  @override
  State<_AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<_AppointmentFormSheet> {
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.titulo ?? widget.tituloInicial ?? '',
  );
  late final _notasCtrl = TextEditingController(
    text: widget.existente?.notas ?? '',
  );
  late DateTime _fecha =
      widget.existente?.fechaHora ?? widget.diaInicial ?? DateTime.now();
  late TimeOfDay _hora = TimeOfDay.fromDateTime(
    widget.existente?.fechaHora ?? DateTime.now(),
  );
  late int _duracion = widget.existente?.duracionMinutos ?? 60;
  late String? _clienteId =
      widget.existente?.clienteId ?? widget.clienteIdFijo;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(context: context, initialTime: _hora);
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un título.')));
      return;
    }
    setState(() => _guardando = true);
    final fechaHora = DateTime(
      _fecha.year,
      _fecha.month,
      _fecha.day,
      _hora.hour,
      _hora.minute,
    );
    final notas = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
    try {
      if (widget.existente != null) {
        await widget.appData.citas.update(
          widget.existente!.copyWith(
            titulo: _tituloCtrl.text.trim(),
            fechaHora: fechaHora,
            duracionMinutos: _duracion,
            clienteId: _clienteId,
            notas: notas,
          ),
        );
      } else {
        await widget.appData.citas.add(
          Cita(
            id: const Uuid().v4(),
            titulo: _tituloCtrl.text.trim(),
            fechaHora: fechaHora,
            duracionMinutos: _duracion,
            clienteId: _clienteId,
            trabajoId: widget.trabajoIdFijo,
            notas: notas,
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
    final trabajoId = widget.existente?.trabajoId ?? widget.trabajoIdFijo;
    // Si el trabajo se borró después de programar la cita, no pasa nada --
    // simplemente no se ofrece el botón (sin referencias rotas visibles).
    final trabajoAsociado = trabajoId != null
        ? widget.appData.trabajos.byId(trabajoId)
        : null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editando ? 'Editar cita' : 'Nueva cita',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título *'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              if (widget.clienteIdFijo != null)
                _CampoFijo(
                  icono: Icons.person_outline,
                  texto:
                      widget.appData.clientes.byId(widget.clienteIdFijo!)?.nombre ??
                      'Cliente',
                )
              else if (widget.appData.clientes.clientes.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _clienteId,
                  decoration: const InputDecoration(
                    labelText: 'Cliente (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin cliente')),
                    ...widget.appData.clientes.clientes.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _clienteId = v),
                ),
              if (trabajoAsociado != null) ...[
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(
                        appData: widget.appData,
                        trabajoId: trabajoAsociado.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: Text('Ver trabajo: ${trabajoAsociado.titulo}'),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirFecha,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirHora,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(_hora.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<int>(
                initialValue: _duracion,
                decoration: const InputDecoration(labelText: 'Duración'),
                items: const [30, 60, 90, 120, 180]
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}min'}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _duracion = v);
                },
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editando ? 'Guardar cambios' : 'Crear cita'),
              ),
              if (editando) ...[
                const SizedBox(height: AppSpace.sm),
                TextButton.icon(
                  onPressed: () async {
                    final confirmar = await confirmarEliminar(
                      context,
                      titulo: '¿Eliminar esta cita?',
                    );
                    if (confirmar) {
                      await widget.appData.citas.delete(widget.existente!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Eliminar cita',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de solo lectura para un dato que viene fijado desde fuera (el
/// cliente, cuando la cita se programa desde la ficha de un trabajo) --
/// mismo criterio visual que un InputDecorator deshabilitado, sin
/// permitir editarlo desde aquí.
class _CampoFijo extends StatelessWidget {
  const _CampoFijo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
