// lib/features/invoices/payment_form_sheet.dart
//
// Registrar un cobro contra una factura emitida. Toda la validación de
// negocio (importe > saldo pendiente, factura no emitida, etc.) vive en
// FacturaRepository.registrarPago -- este formulario solo recoge los
// datos y muestra el error que lance el repositorio si lo hay.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/factura.dart';
import '../../data/models/pago_factura.dart';

Future<void> mostrarFormularioPago(
  BuildContext context, {
  required AppData appData,
  required Factura factura,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentFormSheet(appData: appData, factura: factura),
  );
}

class _PaymentFormSheet extends StatefulWidget {
  const _PaymentFormSheet({required this.appData, required this.factura});

  final AppData appData;
  final Factura factura;

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _importeCtrl = TextEditingController(
    text: widget.factura.saldoPendiente.toStringAsFixed(2),
  );
  final _notaCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  MetodoPago _metodo = MetodoPago.transferencia;

  // Evita que un doble toque en "Registrar cobro" dispare dos llamadas a
  // registrarPago() antes de que la primera termine de persistir.
  bool _guardando = false;

  @override
  void dispose() {
    _importeCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final importe = double.tryParse(_importeCtrl.text.replaceAll(',', '.'));
    if (importe == null || importe <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El importe no es válido.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.appData.facturas.registrarPago(
        widget.factura.id,
        fecha: _fecha,
        importe: importe,
        metodo: _metodo,
        nota: _notaCtrl.text,
      );
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message.toString())));
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Registrar cobro',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Saldo pendiente: ${formatCurrency(widget.factura.saldoPendiente)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _importeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Importe recibido (€) *',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    'Fecha del cobro: '
                    '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                DropdownButtonFormField<MetodoPago>(
                  initialValue: _metodo,
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                  items: MetodoPago.values
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(nombreMetodoPago(m)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _metodo = v);
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _notaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Referencia o nota (opcional)',
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
                      : const Text('Registrar cobro'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
