// lib/features/clients/client_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/cliente.dart';
import '../../data/repositories/cliente_repository.dart';

String? _campoOpcional(TextEditingController c) =>
    c.text.trim().isEmpty ? null : c.text.trim();

Future<void> mostrarFormularioCliente(
  BuildContext context, {
  required ClienteRepository repo,
  Cliente? existente,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClientFormSheet(repo: repo, existente: existente),
  );
}

class _ClientFormSheet extends StatefulWidget {
  const _ClientFormSheet({required this.repo, this.existente});

  final ClienteRepository repo;
  final Cliente? existente;

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(
    text: widget.existente?.nombre ?? '',
  );
  late final _telefonoCtrl = TextEditingController(
    text: widget.existente?.telefono ?? '',
  );
  late final _emailCtrl = TextEditingController(
    text: widget.existente?.email ?? '',
  );
  late final _direccionCtrl = TextEditingController(
    text: widget.existente?.direccion ?? '',
  );
  late final _notasCtrl = TextEditingController(
    text: widget.existente?.notas ?? '',
  );
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  String? _vacio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Obligatorio' : null;

  String? _emailValido(String? valor) {
    if (valor == null || valor.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor.trim());
    return ok ? null : 'Email no válido';
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      if (widget.existente != null) {
        await widget.repo.update(
          widget.existente!.copyWith(
            nombre: _nombreCtrl.text.trim(),
            telefono: _campoOpcional(_telefonoCtrl),
            email: _campoOpcional(_emailCtrl),
            direccion: _campoOpcional(_direccionCtrl),
            notas: _campoOpcional(_notasCtrl),
          ),
        );
      } else {
        await widget.repo.add(
          Cliente(
            id: const Uuid().v4(),
            nombre: _nombreCtrl.text.trim(),
            telefono: _campoOpcional(_telefonoCtrl),
            email: _campoOpcional(_emailCtrl),
            direccion: _campoOpcional(_direccionCtrl),
            notas: _campoOpcional(_notasCtrl),
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  editando ? 'Editar cliente' : 'Nuevo cliente',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o empresa *',
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLines: null,
                  validator: _vacio,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValido,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  maxLines: null,
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 3,
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
                      : Text(editando ? 'Guardar cambios' : 'Crear cliente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
