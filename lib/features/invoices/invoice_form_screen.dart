// lib/features/invoices/invoice_form_screen.dart
//
// Crear/editar una factura en borrador. Solo opera sobre borradores --
// FacturaRepository.update() ya rechaza cambios sobre una factura
// emitida, así que esta pantalla ni siquiera se abre para editar una
// (ver invoice_detail_screen.dart: el botón "Editar" solo aparece en
// borrador). Mismo patrón de conceptos editables que quote_form_screen.
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/concepto_presupuesto.dart';
import '../../data/models/factura.dart';
import '../../data/models/factura_totals.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({
    required this.appData,
    this.clienteIdFijo,
    this.trabajoIdFijo,
    this.presupuestoIdFijo,
    this.existente,
    this.tituloInicial,
    this.conceptosIniciales,
    super.key,
  });

  final AppData appData;
  final String? clienteIdFijo;
  final String? trabajoIdFijo;
  final String? presupuestoIdFijo;
  final Factura? existente;

  /// Título y conceptos sugeridos al crear desde un trabajo (reutiliza su
  /// descripción, y los del presupuesto de origen si lo tiene) -- se
  /// ignoran si [existente] no es null.
  final String? tituloInicial;
  final List<ConceptoPresupuesto>? conceptosIniciales;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
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

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.titulo ?? widget.tituloInicial ?? '',
  );
  late String? _clienteId = widget.existente?.clienteId ?? widget.clienteIdFijo;
  late double _iva = widget.existente?.ivaPorcentaje ?? 21;
  late double _descuento = widget.existente?.descuentoPorcentaje ?? 0;
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

  FacturaTotals get _totales => calcularTotalesFactura(
    _filas.map((f) => f.toModel()).toList(),
    _iva,
    _descuento,
  );

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
        const SnackBar(content: Text('Elige un cliente para la factura.')),
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
    if (_descuento < 0 || _descuento > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El descuento debe estar entre 0 y 100%.'),
        ),
      );
      return;
    }

    final conceptos = conceptosValidos.map((f) => f.toModel()).toList();
    setState(() => _guardando = true);
    try {
      if (widget.existente != null) {
        await widget.appData.facturas.update(
          widget.existente!.copyWith(
            titulo: _tituloCtrl.text.trim(),
            conceptos: conceptos,
            ivaPorcentaje: _iva,
            descuentoPorcentaje: _descuento,
          ),
        );
      } else {
        await widget.appData.facturas.add(
          Factura(
            id: const Uuid().v4(),
            clienteId: _clienteId!,
            trabajoId: widget.trabajoIdFijo,
            presupuestoId: widget.presupuestoIdFijo,
            titulo: _tituloCtrl.text.trim(),
            conceptos: conceptos,
            ivaPorcentaje: _iva,
            descuentoPorcentaje: _descuento,
            creadaEl: DateTime.now(),
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
          title: Text(editando ? 'Editar borrador' : 'Nueva factura'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            160,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.sm + 4),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Se guarda como borrador. El número de factura se '
                      'asigna al emitirla, no antes.',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
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
                Text('Descuento', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _descuento.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(suffixText: '%'),
                    onChanged: (v) => setState(() {
                      _descuento = double.tryParse(v) ?? _descuento;
                      _tocado = true;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilaTotal('Subtotal', _totales.subtotalBruto),
                if (_descuento > 0)
                  _FilaTotal(
                    'Descuento (${_descuento.toStringAsFixed(0)}%)',
                    -_totales.descuento,
                  ),
                _FilaTotal('Base imponible', _totales.baseImponible),
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
                        : Text(editando ? 'Guardar cambios' : 'Guardar borrador'),
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
                    icon: Icon(
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
