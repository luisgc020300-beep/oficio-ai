// lib/features/invoices/invoices_list_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/factura.dart';
import 'invoice_detail_screen.dart';
import 'invoice_form_screen.dart';

enum _FiltroFactura { todas, borrador, pendiente, pagada, vencida, anulada }

String _nombreFiltro(_FiltroFactura f) => switch (f) {
  _FiltroFactura.todas => 'Todas',
  _FiltroFactura.borrador => 'Borrador',
  _FiltroFactura.pendiente => 'Pendientes',
  _FiltroFactura.pagada => 'Pagadas',
  _FiltroFactura.vencida => 'Vencidas',
  _FiltroFactura.anulada => 'Anuladas',
};

bool _coincideFiltro(Factura f, _FiltroFactura filtro) => switch (filtro) {
  _FiltroFactura.todas => true,
  _FiltroFactura.borrador => f.estado == EstadoFactura.borrador,
  _FiltroFactura.anulada => f.estado == EstadoFactura.anulada,
  _FiltroFactura.pagada => f.pagadaCompleta,
  _FiltroFactura.vencida => f.estaVencida(),
  _FiltroFactura.pendiente =>
    f.estado == EstadoFactura.emitida && !f.pagadaCompleta && !f.estaVencida(),
};

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  _FiltroFactura _filtro = _FiltroFactura.todas;
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facturas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceFormScreen(appData: widget.appData),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.appData.facturas,
          widget.appData.clientes,
        ]),
        builder: (context, _) {
          final todas = widget.appData.facturas.facturas;
          if (todas.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Todavía no hay facturas',
              message:
                  'Créalas desde un trabajo terminado, o empieza una aquí.',
              actionLabel: 'Nueva factura',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceFormScreen(appData: widget.appData),
                ),
              ),
            );
          }

          final emitidasNoAnuladas = todas.where(
            (f) => f.estado == EstadoFactura.emitida,
          );
          final totalPendiente = emitidasNoAnuladas.fold<double>(
            0,
            (acc, f) => acc + f.saldoPendiente,
          );
          final vencidas = emitidasNoAnuladas.where((f) => f.estaVencida()).length;

          final porFiltro = todas.where((f) => _coincideFiltro(f, _filtro)).toList();
          final consulta = _busqueda.trim().toLowerCase();
          final filtradas = consulta.isEmpty
              ? porFiltro
              : porFiltro.where((f) {
                  final cliente = widget.appData.clientes.byId(f.clienteId);
                  return f.titulo.toLowerCase().contains(consulta) ||
                      (f.numero?.toLowerCase().contains(consulta) ?? false) ||
                      (cliente?.nombre.toLowerCase().contains(consulta) ?? false);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ResumenMini(
                        texto: '${formatCurrency(totalPendiente)} pendiente',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: _ResumenMini(
                        texto: '$vencidas vencida${vencidas == 1 ? '' : 's'}',
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cliente, título o número...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  children: [
                    for (final f in _FiltroFactura.values) ...[
                      if (f != _FiltroFactura.todas) const SizedBox(width: AppSpace.sm),
                      ChoiceChip(
                        label: Text(_nombreFiltro(f)),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: filtradas.isEmpty
                    ? EmptyState(
                        icon: Icons.filter_list_off,
                        title: 'Sin resultados',
                        message: consulta.isEmpty
                            ? 'Prueba a cambiar el filtro de arriba.'
                            : 'Nada coincide con "$_busqueda" en este filtro.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.sm,
                          0,
                          AppSpace.sm,
                          AppSpace.lg,
                        ),
                        itemCount: filtradas.length,
                        separatorBuilder: (_, _) => const Divider(indent: 68, height: 1),
                        itemBuilder: (context, i) {
                          final f = filtradas[i];
                          final cliente = widget.appData.clientes.byId(f.clienteId);
                          return AppListTile(
                            icon: Icons.receipt_long_outlined,
                            iconColor: colorEstadoFactura(f),
                            title: f.numero != null ? '${f.numero} · ${f.titulo}' : f.titulo,
                            esDemo: f.esDemo,
                            subtitle:
                                '${cliente?.nombre ?? 'Sin cliente'} · ${etiquetaFactura(f)}',
                            trailing: Text(
                              formatCurrency(f.totales.total),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(
                                  appData: widget.appData,
                                  facturaId: f.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResumenMini extends StatelessWidget {
  const _ResumenMini({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
