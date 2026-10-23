// lib/features/jobs/job_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_data.dart';
import '../../data/models/trabajo.dart';

Future<void> mostrarFormularioTrabajo(
  BuildContext context, {
  required AppData appData,
  String? clienteId,
  Trabajo? existente,
  String? tituloInicial,
  String? presupuestoIdFijo,
}) {
  if (appData.clientes.clientes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea antes un cliente para poder asignarle un trabajo.'),
      ),
    );
    return Future.value();
  }
  // Comprueba la relación existente antes de abrir el formulario -- si ya
  // hay un trabajo para este presupuesto, no tiene sentido ni dejar crear
  // uno nuevo (encargo, sección 3: "evita duplicados").
  if (presupuestoIdFijo != null &&
      appData.trabajos.porPresupuesto(presupuestoIdFijo).isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ya existe un trabajo creado desde este presupuesto.'),
      ),
    );
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JobFormSheet(
      appData: appData,
      clienteIdFijo: clienteId,
      existente: existente,
      tituloInicial: tituloInicial,
      presupuestoIdFijo: presupuestoIdFijo,
    ),
  );
}

class _JobFormSheet extends StatefulWidget {
  const _JobFormSheet({
    required this.appData,
    this.clienteIdFijo,
    this.existente,
    this.tituloInicial,
    this.presupuestoIdFijo,
  });

  final AppData appData;
  final String? clienteIdFijo;
  final Trabajo? existente;

  /// Título sugerido al crear desde un presupuesto aceptado -- ignorado
  /// si [existente] no es null.
  final String? tituloInicial;

  /// Presupuesto de origen cuando el trabajo se crea desde uno aceptado
  /// (ver quote_detail_screen.dart). Nunca se usa para modificar ese
  /// presupuesto -- solo queda como referencia en el trabajo nuevo.
  final String? presupuestoIdFijo;

  @override
  State<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends State<_JobFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.titulo ?? widget.tituloInicial ?? '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.existente?.descripcion ?? '',
  );
  late final _direccionCtrl = TextEditingController(
    text: widget.existente?.direccion ?? '',
  );
  late String? _clienteId = widget.existente?.clienteId ?? widget.clienteIdFijo;
  late EstadoTrabajo _estado = widget.existente?.estado ?? EstadoTrabajo.pendiente;
  late DateTime? _fechaProgramada = widget.existente?.fechaProgramada;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (fecha != null) setState(() => _fechaProgramada = fecha);
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_clienteId == null) return;
    // Repetimos la comprobación justo antes de guardar (no solo al abrir
    // el formulario): si dos intentos de creación llegan aquí casi a la
    // vez para el mismo presupuesto, el segundo no debe crear un
    // duplicado -- encargo, sección 3.
    if (widget.existente == null &&
        widget.presupuestoIdFijo != null &&
        widget.appData.trabajos
            .porPresupuesto(widget.presupuestoIdFijo!)
            .isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya existe un trabajo creado desde este presupuesto.'),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    setState(() => _guardando = true);
    try {
      final descripcion = _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim();
      final direccion = _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim();
      if (widget.existente != null) {
        await widget.appData.trabajos.update(
          widget.existente!.copyWith(
            titulo: _tituloCtrl.text.trim(),
            descripcion: descripcion,
            direccion: direccion,
            estado: _estado,
            fechaProgramada: _fechaProgramada,
          ),
        );
      } else {
        await widget.appData.trabajos.add(
          Trabajo(
            id: const Uuid().v4(),
            clienteId: _clienteId!,
            titulo: _tituloCtrl.text.trim(),
            descripcion: descripcion,
            direccion: direccion,
            estado: _estado,
            creadoEl: DateTime.now(),
            fechaProgramada: _fechaProgramada,
            presupuestoId: widget.presupuestoIdFijo,
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  editando ? 'Editar trabajo' : 'Nuevo trabajo',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                if (widget.clienteIdFijo == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: DropdownButtonFormField<String>(
                      initialValue: _clienteId,
                      decoration: const InputDecoration(labelText: 'Cliente *'),
                      items: widget.appData.clientes.clientes
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _clienteId = v),
                      validator: (v) => v == null ? 'Elige un cliente' : null,
                    ),
                  ),
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del trabajo',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                DropdownButtonFormField<EstadoTrabajo>(
                  initialValue: _estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: EstadoTrabajo.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(nombreEstadoTrabajo(e)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _estado = v);
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _fechaProgramada == null
                        ? 'Sin fecha programada'
                        : '${_fechaProgramada!.day}/${_fechaProgramada!.month}/${_fechaProgramada!.year}',
                  ),
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
                      : Text(editando ? 'Guardar cambios' : 'Crear trabajo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
