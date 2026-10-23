// lib/core/widgets/confirm_delete_dialog.dart
//
// Confirmación única para cualquier acción destructiva -- antes había
// tres AlertDialog casi idénticos duplicados en clientes/trabajos/
// presupuestos. Todas las eliminaciones de la app pasan por aquí.
import 'package:flutter/material.dart';

Future<bool> confirmarEliminar(
  BuildContext context, {
  required String titulo,
  String? mensaje,
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: mensaje != null ? Text(mensaje) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmar ?? false;
}
