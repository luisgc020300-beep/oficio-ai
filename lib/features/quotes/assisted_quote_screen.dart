// lib/features/quotes/assisted_quote_screen.dart
//
// Paso 1 del presupuesto asistido: cliente + descripción en lenguaje
// natural. Al generar, empuja la MISMA pantalla de revisión que ya usa
// la creación manual (QuoteFormScreen) precargada con la propuesta --
// no hay una UI de revisión paralela, así que la edición, el cálculo de
// IVA/total y el guardado son exactamente los que ya existen y ya están
// testeados.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/local_engine_badge.dart';
import '../../data/app_data.dart';
import '../../data/assistant/local_quote_generator.dart';
import '../../data/assistant/propuesta_presupuesto.dart';
import '../../data/assistant/quote_generator.dart';
import 'quote_form_screen.dart';

class AssistedQuoteScreen extends StatefulWidget {
  const AssistedQuoteScreen({
    required this.appData,
    this.clienteIdFijo,
    this.generator,
    super.key,
  });

  final AppData appData;
  final String? clienteIdFijo;

  /// Inyectable para tests -- por defecto usa el motor local de reglas.
  final QuoteGenerator? generator;

  @override
  State<AssistedQuoteScreen> createState() => _AssistedQuoteScreenState();
}

class _AssistedQuoteScreenState extends State<AssistedQuoteScreen> {
  late final QuoteGenerator _generator = widget.generator ?? LocalQuoteGenerator();
  final _descripcionCtrl = TextEditingController();
  late String? _clienteId = widget.clienteIdFijo;
  bool _generando = false;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _generar() async {
    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige primero un cliente.')),
      );
      return;
    }
    final descripcion = _descripcionCtrl.text.trim();
    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el trabajo para poder generar una propuesta.')),
      );
      return;
    }

    setState(() => _generando = true);
    PropuestaPresupuesto propuesta;
    try {
      propuesta = await _generator.generar(descripcion);
    } catch (e) {
      if (mounted) {
        setState(() => _generando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo generar la propuesta. Inténtalo de nuevo.'),
            action: SnackBarAction(label: 'Reintentar', onPressed: _generar),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _generando = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteFormScreen(
          appData: widget.appData,
          clienteIdFijo: _clienteId,
          tituloInicial: propuesta.tituloSugerido,
          conceptosIniciales: propuesta.conceptos,
          avisoGeneracion: propuesta.mensaje,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sinClientes = widget.appData.clientes.clientes.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear presupuesto con ayuda')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          const LocalEngineBadge(),
          const SizedBox(height: AppSpace.md),
          Text(
            'Describe el trabajo con tus palabras y te propongo una lista '
            'de conceptos para empezar. Podrás editar, añadir o quitar '
            'lo que haga falta antes de guardar nada.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.lg),
          if (sinClientes)
            Card(
              color: AppColors.warningTint,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Text(
                  'Todavía no tienes ningún cliente. Crea uno primero desde '
                  'la pestaña Clientes para poder asignarle este presupuesto.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _clienteId,
              decoration: const InputDecoration(labelText: 'Cliente *'),
              items: widget.appData.clientes.clientes
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                  .toList(),
              onChanged: (v) => setState(() => _clienteId = v),
            ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _descripcionCtrl,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Describe el trabajo *',
              alignLabelWithHint: true,
              hintText:
                  'Por ejemplo: "cambiar el grifo de la cocina", "revisar '
                  'una fuga en el baño", "instalar una lámpara en el '
                  'salón"...',
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: (_generando || sinClientes) ? null : _generar,
            icon: _generando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(_generando ? 'Generando...' : 'Generar propuesta'),
          ),
        ],
      ),
    );
  }
}
