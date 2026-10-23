// lib/features/quotes/quote_form_screen.dart
//
// Conceptos editables con cantidad, precio, subtotal, IVA configurable y
// total -- todo recalculado en vivo con calcularTotales() (la misma
// función que cubren los tests unitarios de quote_totals_test.dart).
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/concepto_presupuesto.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/quote_totals.dart';

class QuoteFormScreen extends StatefulWidget {
  const QuoteFormScreen({
    required this.appData,
    this.clienteIdFijo,
    this.trabajoIdFijo,
    this.existente,
    this.tituloInicial,
    this.conceptosIniciales,
    this.avisoGeneracion,
    super.key,
  });

  final AppData appData;
  final String? clienteIdFijo;
  final String? trabajoIdFijo;
  final Presupuesto? existente;

  /// Título y conceptos sugeridos al llegar desde el flujo de presupuesto
  /// asistido (ver assisted_quote_screen.dart) -- ignorados si [existente]
  /// no es null (editar siempre parte de los datos ya guardados).
  final String? tituloInicial;
  final List<ConceptoPresupuesto>? conceptosIniciales;

  /// Mensaje del generador explicando qué ha reconocido (o por qué la
  /// propuesta es genérica) -- se muestra como aviso hasta que el
  /// profesional guarda, para no confundir una sugerencia con un dato ya
  /// confirmado.
  final String? avisoGeneracion;

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _FilaConcepto {
  _FilaConcepto({
    String? id,
    String descripcion = '',
    double cantidad = 1,
    double precio = 0,
  }) : id = id ?? const Uuid().v4(),
       descripcionCtrl = TextEditingController(text: descripcion),
       cantidadCtrl = TextEditingController(
         text: cantidad == cantidad.roundToDouble()
             ? cantidad.toStringAsFixed(0)
             : cantidad.toString(),
       ),
       precioCtrl = TextEditingController(text: precio.toStringAsFixed(2));

  final String id;
  final TextEditingController descripcionCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController precioCtrl;

  double get cantidad =>
      double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
  double get precio =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;

  /// A diferencia de [cantidad]/[precio] (que devuelven 0 si el texto no
  /// es un número válido, para que la previsualización en vivo nunca
  /// falle mientras se escribe), estos dos son null cuando el texto no
  /// se puede interpretar -- se usan solo al guardar, para distinguir
  /// "cero de verdad" de "esto no es un número" (sección 4 del encargo:
  /// validar cantidades y precios, no asumir 0 en silencio).
  double? get cantidadValidada =>
      double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
  double? get precioValidado =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.'));

  ConceptoPresupuesto toModel() => ConceptoPresupuesto(
    id: id,
    descripcion: descripcionCtrl.text.trim(),
    cantidad: cantidad,
    precioUnitario: precio,
  );

  void dispose() {
    descripcionCtrl.dispose();
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.titulo ?? widget.tituloInicial ?? '',
  );
  late String? _clienteId = widget.existente?.clienteId ?? widget.clienteIdFijo;
  late double _iva = widget.existente?.ivaPorcentaje ?? 21;
  late final List<_FilaConcepto> _filas = widget.existente != null
      ? widget.existente!.conceptos
            .map(
              (c) => _FilaConcepto(
                id: c.id,
                descripcion: c.descripcion,
                cantidad: c.cantidad,
                precio: c.precioUnitario,
              ),
            )
            .toList()
      : (widget.conceptosIniciales?.isNotEmpty ?? false)
      ? widget.conceptosIniciales!
            .map(
              (c) => _FilaConcepto(
                id: c.id,
                descripcion: c.descripcion,
                cantidad: c.cantidad,
                precio: c.precioUnitario,
              ),
            )
            .toList()
      : [_FilaConcepto()];
  bool _guardando = false;

  /// true en cuanto el usuario toca algo -- distingue "formulario
  /// precargado por el asistente sin tocar" (se puede salir sin avisar)
  /// de "ya he empezado a editar" (avisa antes de descartarlo).
  bool _tocado = false;

  /// Evita dos diálogos de "¿Descartar los cambios?" apilados si llegan
  /// dos intentos de navegación seguidos (p. ej. doble toque en atrás)
  /// antes de que el primero se haya cerrado.
  bool _confirmandoDescarte = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  QuoteTotals get _totales =>
      calcularTotales(_filas.map((f) => f.toModel()).toList(), _iva);

  void _anadirConcepto() => setState(() {
    _filas.add(_FilaConcepto());
    _tocado = true;
  });

  void _quitarConcepto(int i) => setState(() {
    _filas[i].dispose();
    _filas.removeAt(i);
    _tocado = true;
  });

  Future<void> _guardar() async {
    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige un cliente para el presupuesto.')),
      );
      return;
    }
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un título.')));
      return;
    }
    final conceptosValidos = _filas
        .where((f) => f.descripcionCtrl.text.trim().isNotEmpty)
        .toList();
    if (conceptosValidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade al menos un concepto con descripción.'),
        ),
      );
      return;
    }
    // Cantidad/precio por línea: no se asume 0 en silencio si lo escrito
    // no es un número -- se avisa con el concepto concreto implicado.
    for (final f in conceptosValidos) {
      final cantidad = f.cantidadValidada;
      if (cantidad == null || cantidad <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La cantidad de "${f.descripcionCtrl.text.trim()}" no es válida.',
            ),
          ),
        );
        return;
      }
      final precio = f.precioValidado;
      if (precio == null || precio < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El precio de "${f.descripcionCtrl.text.trim()}" no es válido.',
            ),
          ),
        );
        return;
      }
    }
    if (_iva < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El IVA no puede ser negativo.')),
      );
      return;
    }

    final conceptos = conceptosValidos.map((f) => f.toModel()).toList();
    final totales = calcularTotales(conceptos, _iva);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Guardar este presupuesto?'),
        content: Text(
          '${_tituloCtrl.text.trim()}\n'
          '${conceptos.length} concepto${conceptos.length == 1 ? '' : 's'} · '
          'Total ${formatCurrency(totales.total)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir revisando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      if (widget.existente != null) {
        await widget.appData.presupuestos.update(
          widget.existente!.copyWith(
            titulo: _tituloCtrl.text.trim(),
            conceptos: conceptos,
            ivaPorcentaje: _iva,
          ),
        );
      } else {
        await widget.appData.presupuestos.add(
          Presupuesto(
            id: const Uuid().v4(),
            clienteId: _clienteId!,
            trabajoId: widget.trabajoIdFijo,
            titulo: _tituloCtrl.text.trim(),
            conceptos: conceptos,
            ivaPorcentaje: _iva,
            estado: EstadoPresupuesto.borrador,
            creadoEl: DateTime.now(),
          ),
        );
      }
      _tocado = false;
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarDescartar() async {
    if (_confirmandoDescarte) return;
    _confirmandoDescarte = true;
    try {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Descartar los cambios?'),
          content: const Text('Se perderán los cambios que no has guardado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (descartar == true && mounted) Navigator.pop(context);
    } finally {
      _confirmandoDescarte = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    return PopScope(
      canPop: !_tocado,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmarDescartar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editando ? 'Editar presupuesto' : 'Nuevo presupuesto'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            140,
          ),
          children: [
            if (widget.avisoGeneracion != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpace.sm + 4),
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: AppColors.accentStrong,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        '${widget.avisoGeneracion!}\n\nEsto es una sugerencia del motor local, todavía sin confirmar -- edita lo que haga falta antes de guardar.',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
            ],
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
                  onChanged: (v) => setState(() {
                    _clienteId = v;
                    _tocado = true;
                  }),
                ),
              ),
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título *'),
              textCapitalization: TextCapitalization.sentences,
              // setState -- sin esto, PopScope(canPop: !_tocado, ...) se
              // queda con el valor construido la última vez que se
              // reconstruyó el widget y nunca refleja este cambio si es
              // el único que se toca (mismo bug corregido en
              // business_settings_screen.dart, iteración 6.1).
              onChanged: (_) {
                if (!_tocado) setState(() => _tocado = true);
              },
            ),
            const SizedBox(height: AppSpace.lg),
            Text('Conceptos', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < _filas.length; i++)
              _FilaConceptoWidget(
                fila: _filas[i],
                onChanged: () => setState(() => _tocado = true),
                onQuitar: _filas.length > 1 ? () => _quitarConcepto(i) : null,
              ),
            OutlinedButton.icon(
              onPressed: _anadirConcepto,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir concepto'),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Text('IVA', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _iva.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(suffixText: '%'),
                    onChanged: (v) => setState(() {
                      _iva = double.tryParse(v) ?? _iva;
                      _tocado = true;
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomSheet: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilaTotal('Subtotal', _totales.subtotal),
                _FilaTotal('IVA (${_iva.toStringAsFixed(0)}%)', _totales.iva),
                const Divider(height: AppSpace.md),
                _FilaTotal('Total', _totales.total, destacado: true),
                const SizedBox(height: AppSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
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
                        : Text(
                            editando ? 'Guardar cambios' : 'Crear presupuesto',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaConceptoWidget extends StatelessWidget {
  const _FilaConceptoWidget({
    required this.fila,
    required this.onChanged,
    this.onQuitar,
  });

  final _FilaConcepto fila;
  final VoidCallback onChanged;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fila.descripcionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                if (onQuitar != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.inkFaint,
                    ),
                    onPressed: onQuitar,
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fila.cantidadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: TextField(
                    controller: fila.precioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio (€)',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  width: 78,
                  child: Text(
                    formatCurrency(fila.cantidad * fila.precio),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal(this.label, this.valor, {this.destacado = false});

  final String label;
  final double valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.primary)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatCurrency(valor), style: style),
        ],
      ),
    );
  }
}
