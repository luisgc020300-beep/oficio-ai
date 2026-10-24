// lib/features/invoices/invoice_rectification_screen.dart
//
// Crear y emitir una factura rectificativa a partir de una ya emitida
// (iteración 8, art. 15 RD 1619/2012). A diferencia de
// invoice_form_screen.dart, los importes SÍ pueden ser negativos --
// una rectificativa que reduce lo facturado se representa con un
// precio unitario negativo, no es un error de los datos (ver
// _FilaRectificacion más abajo, que por eso no reutiliza
// _FilaConceptoWidget de invoice_form_screen.dart).
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_data.dart';
import '../../data/models/cliente_snapshot.dart';
import '../../data/models/concepto_presupuesto.dart';
import '../../data/models/factura.dart';
import '../../data/models/factura_totals.dart';
import 'invoice_detail_screen.dart';
import 'invoice_pdf_preview_screen.dart';

class InvoiceRectificationScreen extends StatefulWidget {
  const InvoiceRectificationScreen({
    required this.appData,
    required this.facturaOriginal,
    super.key,
  });

  final AppData appData;
  final Factura facturaOriginal;

  @override
  State<InvoiceRectificationScreen> createState() => _InvoiceRectificationScreenState();
}

class _FilaRectificacion {
  _FilaRectificacion({
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

  double? get cantidadValidada =>
      double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
  double? get precioValidado =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.'));

  ConceptoPresupuesto toModel() => ConceptoPresupuesto(
    id: id,
    descripcion: descripcionCtrl.text.trim(),
    cantidad: cantidadValidada ?? 0,
    precioUnitario: precioValidado ?? 0,
  );

  void dispose() {
    descripcionCtrl.dispose();
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _InvoiceRectificationScreenState extends State<InvoiceRectificationScreen> {
  final _motivoCtrl = TextEditingController();
  ModalidadRectificacion _modalidad = ModalidadRectificacion.porDiferencias;
  late List<_FilaRectificacion> _filas = _filasIniciales(_modalidad);
  /// Deshabilita el botón desde el primer toque -- sin esto, el diálogo
  /// de confirmación podría abrirse dos veces con un doble toque rápido
  /// (ver _emitir()).
  bool _bloqueado = false;

  /// Aparte de [_bloqueado]: solo true durante el trabajo real (crear +
  /// emitir), para pintar el indicador de carga. Deliberadamente NO se
  /// activa mientras el diálogo de confirmación está abierto esperando
  /// al usuario -- un CircularProgressIndicator indeterminado anima sin
  /// parar, y mantenerlo en pantalla durante una espera de duración
  /// arbitraria (la decisión del usuario) le da a pumpAndSettle() en
  /// los tests algo que nunca termina de asentarse.
  bool _guardando = false;

  List<_FilaRectificacion> _filasIniciales(ModalidadRectificacion modalidad) =>
      modalidad == ModalidadRectificacion.importeResultante
          // Se parte de una copia de los conceptos originales -- el
          // profesional los edita hasta dejar los importes TAL Y COMO
          // deben quedar tras la corrección (art. 15.5.b).
          ? widget.facturaOriginal.conceptos
                .map(
                  (c) => _FilaRectificacion(
                    descripcion: c.descripcion,
                    cantidad: c.cantidad,
                    precio: c.precioUnitario,
                  ),
                )
                .toList()
          // Una sola fila vacía para que el profesional escriba
          // directamente la diferencia (positiva o negativa).
          : [_FilaRectificacion(descripcion: 'Corrección')];

  @override
  void dispose() {
    _motivoCtrl.dispose();
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  FacturaTotals get _totales => calcularTotalesFactura(
    _filas.map((f) => f.toModel()).toList(),
    widget.facturaOriginal.ivaPorcentaje,
    widget.facturaOriginal.descuentoPorcentaje,
  );

  double get _importeRectificacion =>
      _modalidad == ModalidadRectificacion.importeResultante
          ? calcularImporteRectificacion(
              totalOriginal: widget.facturaOriginal.totales.total,
              totalCorregido: _totales.total,
            )
          : _totales.total;

  void _cambiarModalidad(ModalidadRectificacion m) {
    if (m == _modalidad) return;
    setState(() {
      _modalidad = m;
      for (final f in _filas) {
        f.dispose();
      }
      _filas = _filasIniciales(m);
    });
  }

  void _anadirConcepto() => setState(() {
    _filas.add(_FilaRectificacion());
  });

  void _quitarConcepto(int i) => setState(() {
    _filas[i].dispose();
    _filas.removeAt(i);
  });

  /// Construye la rectificativa EN BORRADOR, sin guardarla -- la usan
  /// tanto la vista previa (que nunca persiste nada) como _emitir() (que
  /// la guarda con FacturaRepository.add() antes de emitirla).
  Factura _borrador() => Factura(
    id: const Uuid().v4(),
    clienteId: widget.facturaOriginal.clienteId,
    titulo: 'Rectificativa de ${widget.facturaOriginal.numero ?? widget.facturaOriginal.titulo}',
    conceptos: _filas.map((f) => f.toModel()).toList(),
    ivaPorcentaje: widget.facturaOriginal.ivaPorcentaje,
    descuentoPorcentaje: widget.facturaOriginal.descuentoPorcentaje,
    creadaEl: DateTime.now(),
    tipoDocumento: TipoDocumentoFactura.rectificativa,
    serie: serieRectificativas,
    facturaOriginalId: widget.facturaOriginal.id,
    motivoRectificacion: _motivoCtrl.text.trim(),
    modalidadRectificacion: _modalidad,
  );

  Future<void> _previsualizar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfPreviewScreen(appData: widget.appData, factura: _borrador()),
      ),
    );
  }

  Future<void> _emitir() async {
    // _bloqueado se fija aquí mismo, antes de validar o abrir el
    // diálogo -- no solo tras confirmarlo -- para que el botón quede
    // deshabilitado desde el primer toque. Un doble toque rápido en
    // "Emitir rectificativa" (antes de que el diálogo llegue a
    // aparecer) no debe poder abrir el flujo dos veces ni, mucho menos,
    // crear dos rectificativas (encargo iteración 8, sección 4.5).
    if (_bloqueado) return;
    setState(() => _bloqueado = true);
    try {
      if (_motivoCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica el motivo de la rectificación.')),
        );
        return;
      }
      final conceptosValidos = _filas
          .where((f) => f.descripcionCtrl.text.trim().isNotEmpty)
          .toList();
      if (conceptosValidos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade al menos un concepto con descripción.')),
        );
        return;
      }
      for (final f in conceptosValidos) {
        final cantidad = f.cantidadValidada;
        if (cantidad == null || cantidad <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La cantidad de "${f.descripcionCtrl.text.trim()}" no es válida.'),
            ),
          );
          return;
        }
        // El precio SÍ puede ser negativo (ver nota de cabecera) -- solo
        // se rechaza si no es un número en absoluto.
        if (f.precioValidado == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('El precio de "${f.descripcionCtrl.text.trim()}" no es válido.'),
            ),
          );
          return;
        }
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Emitir esta rectificativa?'),
          content: Text(
            'Se le asignará su propia numeración (serie "$serieRectificativas") y '
            'no se podrá modificar después. La factura original '
            '(${widget.facturaOriginal.numero}) no cambia.\n\n'
            'Importe de la rectificación: ${formatCurrency(_importeRectificacion)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Emitir'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      setState(() => _guardando = true);

      final borrador = _borrador();
      await widget.appData.facturas.add(borrador);
      final datosNegocio = widget.appData.negocio.datos;
      final cliente = widget.appData.clientes.byId(widget.facturaOriginal.clienteId);
      final emitida = await widget.appData.facturas.emitir(
        borrador.id,
        datosEmisor: datosNegocio!,
        datosCliente: cliente != null ? ClienteSnapshot.desde(cliente) : null,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(appData: widget.appData, facturaId: emitida.id),
        ),
      );
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _bloqueado = false;
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.facturaOriginal;
    return Scaffold(
      appBar: AppBar(title: const Text('Rectificar factura')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 160),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              title: Text('Rectifica a ${original.numero ?? original.titulo}'),
              subtitle: Text(
                'Total original: ${formatCurrency(original.totales.total)}'
                '${original.fechaEmision != null ? ' · ${formatDate(original.fechaEmision!)}' : ''}',
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _motivoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo de la rectificación *'),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Modalidad', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.sm),
          SegmentedButton<ModalidadRectificacion>(
            segments: const [
              ButtonSegment(
                value: ModalidadRectificacion.porDiferencias,
                label: Text('Por diferencias'),
              ),
              ButtonSegment(
                value: ModalidadRectificacion.importeResultante,
                label: Text('Importe resultante'),
              ),
            ],
            selected: {_modalidad},
            onSelectionChanged: (s) => _cambiarModalidad(s.first),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            _modalidad == ModalidadRectificacion.porDiferencias
                ? 'Escribe solo la diferencia a corregir -- un precio negativo '
                      'reduce lo facturado, uno positivo lo aumenta.'
                : 'Edita los conceptos hasta dejar los importes tal y como '
                      'deben quedar tras la corrección.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Conceptos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.sm),
          for (var i = 0; i < _filas.length; i++)
            _FilaRectificacionWidget(
              fila: _filas[i],
              onChanged: () => setState(() {}),
              onQuitar: _filas.length > 1 ? () => _quitarConcepto(i) : null,
            ),
          OutlinedButton.icon(
            onPressed: _anadirConcepto,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir concepto'),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _modalidad == ModalidadRectificacion.importeResultante
                        ? 'Importe de la rectificación'
                        : 'Total',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    formatCurrency(_importeRectificacion),
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _bloqueado ? null : _previsualizar,
                      child: const Text('Vista previa'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _bloqueado ? null : _emitir,
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Emitir rectificativa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaRectificacionWidget extends StatelessWidget {
  const _FilaRectificacionWidget({
    required this.fila,
    required this.onChanged,
    this.onQuitar,
  });

  final _FilaRectificacion fila;
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
                    decoration: const InputDecoration(labelText: 'Descripción', isDense: true),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                if (onQuitar != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.inkFaint),
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
                    decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: TextField(
                    controller: fila.precioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio (€)',
                      helperText: 'Negativo si reduce lo facturado',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  width: 78,
                  child: Text(
                    formatCurrency((fila.cantidadValidada ?? 0) * (fila.precioValidado ?? 0)),
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
