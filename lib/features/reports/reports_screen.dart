// lib/features/reports/reports_screen.dart
//
// Informes y estadísticas del negocio (iteración 12) -- complementa al
// dashboard, no lo duplica: Inicio ya muestra el resumen del MES actual
// y la evolución de los últimos 6 meses (ver dashboard_screen.dart);
// aquí se puede elegir un periodo más amplio (trimestre, año, todo) y
// se añaden cifras que el dashboard no trae: gastos por categoría,
// trabajos por estado, tasa de conversión de presupuestos y los
// clientes que más facturan. Todo se calcula al vuelo sobre los
// repositorios existentes -- no hay ningún modelo ni almacenamiento
// nuevo.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/app_data.dart';
import '../../data/models/factura.dart';
import '../../data/models/gasto.dart';
import '../../data/models/presupuesto.dart';
import '../../data/models/trabajo.dart';
import '../clients/client_detail_screen.dart';

enum Periodo { esteMes, esteTrimestre, esteAnio, todo }

String nombrePeriodo(Periodo p) => switch (p) {
  Periodo.esteMes => 'Este mes',
  Periodo.esteTrimestre => 'Este trimestre',
  Periodo.esteAnio => 'Este año',
  Periodo.todo => 'Todo',
};

/// Rango [inicio, fin) del periodo que contiene [ahora]. [Periodo.todo]
/// no tiene límites -- se representa como `null` en vez de inventar una
/// fecha de inicio arbitraria.
(DateTime, DateTime)? rangoPeriodo(Periodo p, DateTime ahora) {
  switch (p) {
    case Periodo.esteMes:
      return (DateTime(ahora.year, ahora.month), DateTime(ahora.year, ahora.month + 1));
    case Periodo.esteTrimestre:
      final trimestre = (ahora.month - 1) ~/ 3; // 0..3
      final mesInicio = trimestre * 3 + 1;
      return (DateTime(ahora.year, mesInicio), DateTime(ahora.year, mesInicio + 3));
    case Periodo.esteAnio:
      return (DateTime(ahora.year), DateTime(ahora.year + 1));
    case Periodo.todo:
      return null;
  }
}

bool _enRango(DateTime fecha, (DateTime, DateTime)? rango) {
  if (rango == null) return true;
  final (inicio, fin) = rango;
  return !fecha.isBefore(inicio) && fecha.isBefore(fin);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Periodo _periodo = Periodo.esteMes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.appData.facturas,
        widget.appData.gastos,
        widget.appData.trabajos,
        widget.appData.presupuestos,
        widget.appData.clientes,
      ]),
      builder: (context, _) {
        final ahora = DateTime.now();
        final rango = rangoPeriodo(_periodo, ahora);

        // Facturación: igual que en el dashboard, agrupada por fecha de
        // EMISIÓN (nunca de creación del borrador); los cobros, por la
        // fecha EFECTIVA del pago -- son fechas distintas a propósito.
        // f.importeFacturacion, no f.totales.total, para no contar dos
        // veces una rectificativa "importe resultante" (ver
        // Factura.importeFacturacion).
        final facturasEmitidas = widget.appData.facturas.facturas
            .where((f) => f.estado == EstadoFactura.emitida)
            .toList();
        final facturasDelPeriodo = facturasEmitidas
            .where((f) => f.fechaEmision != null && _enRango(f.fechaEmision!, rango))
            .toList();
        final totalFacturado = facturasDelPeriodo.fold<double>(
          0,
          (acc, f) => acc + f.importeFacturacion,
        );
        final totalCobrado = facturasEmitidas
            .expand((f) => f.pagos)
            .where((p) => _enRango(p.fecha, rango))
            .fold<double>(0, (acc, p) => acc + p.importe);
        // El saldo pendiente es una fotografía de AHORA, no del periodo
        // -- una factura pendiente de cobro sigue pendiente aunque se
        // emitiera fuera del rango elegido, así que se calcula aparte,
        // sobre todas las facturas emitidas.
        final saldoPendiente = facturasEmitidas.fold<double>(0, (acc, f) => acc + f.saldoPendiente);

        // Gastos del periodo, solo los activos -- uno anulado nunca
        // computa (ver Gasto.estado).
        final gastosDelPeriodo = widget.appData.gastos.activos
            .where((g) => _enRango(g.fecha, rango))
            .toList();
        final totalGastado = gastosDelPeriodo.fold<double>(0, (acc, g) => acc + g.importe);
        final gastosPorCategoria = <CategoriaGasto, double>{};
        for (final g in gastosDelPeriodo) {
          gastosPorCategoria[g.categoria] = (gastosPorCategoria[g.categoria] ?? 0) + g.importe;
        }
        final categoriasOrdenadas = gastosPorCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Igual que en el dashboard: estimación agregada, nunca
        // "beneficio neto" (faltan costes indirectos, impuestos...).
        final margenEstimado = totalFacturado - totalGastado;

        // Trabajos creados en el periodo, por estado -- no es "trabajos
        // activos ahora mismo" (eso ya lo muestra Inicio), es cuántos
        // se dieron de alta en el rango elegido.
        final trabajosDelPeriodo = widget.appData.trabajos.trabajos
            .where((t) => _enRango(t.creadoEl, rango))
            .toList();
        final trabajosPorEstado = {
          for (final estado in EstadoTrabajo.values)
            estado: trabajosDelPeriodo.where((t) => t.estado == estado).length,
        };

        // Presupuestos creados en el periodo, por estado -- la tasa de
        // conversión solo cuenta los ya DECIDIDOS (aceptado/rechazado);
        // uno enviado y todavía sin respuesta no es ni un sí ni un no,
        // así que no entra en el cálculo (no se inventa una tendencia).
        final presupuestosDelPeriodo = widget.appData.presupuestos.presupuestos
            .where((p) => _enRango(p.creadoEl, rango))
            .toList();
        final presupuestosEnviados = presupuestosDelPeriodo
            .where((p) => p.estado == EstadoPresupuesto.enviado)
            .length;
        final presupuestosAceptados = presupuestosDelPeriodo
            .where((p) => p.estado == EstadoPresupuesto.aceptado)
            .length;
        final presupuestosRechazados = presupuestosDelPeriodo
            .where((p) => p.estado == EstadoPresupuesto.rechazado)
            .length;
        final decididos = presupuestosAceptados + presupuestosRechazados;
        final tasaConversion = decididos == 0 ? null : presupuestosAceptados / decididos * 100;

        // Top clientes por facturación del periodo -- solo clientes con
        // algo facturado, nunca una lista rellena con ceros inventados.
        final facturadoPorCliente = <String, double>{};
        for (final f in facturasDelPeriodo) {
          facturadoPorCliente[f.clienteId] =
              (facturadoPorCliente[f.clienteId] ?? 0) + f.importeFacturacion;
        }
        final topClientes = facturadoPorCliente.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5Clientes = topClientes.take(5).toList();

        final hayAlgo =
            facturasDelPeriodo.isNotEmpty ||
            gastosDelPeriodo.isNotEmpty ||
            trabajosDelPeriodo.isNotEmpty ||
            presupuestosDelPeriodo.isNotEmpty;

        return Scaffold(
          appBar: AppBar(title: const Text('Informes')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  key: const Key('informesPeriodoChips'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in Periodo.values) ...[
                      ChoiceChip(
                        label: Text(nombrePeriodo(p)),
                        selected: _periodo == p,
                        onSelected: (_) => setState(() => _periodo = p),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (!hayAlgo)
                const EmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'Sin datos en este periodo',
                  message: 'Todavía no hay facturas, gastos, trabajos ni presupuestos en el '
                      'periodo elegido.',
                )
              else ...[
                Text('Facturación', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpace.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      children: [
                        _FilaInforme('Facturado', formatCurrency(totalFacturado)),
                        _FilaInforme('Cobrado', formatCurrency(totalCobrado)),
                        _FilaInforme(
                          'Pendiente de cobro (a día de hoy)',
                          formatCurrency(saldoPendiente),
                        ),
                        const Divider(height: AppSpace.lg),
                        _FilaInforme(
                          'Margen estimado',
                          formatCurrency(margenEstimado),
                          destacado: true,
                          positivo: margenEstimado >= 0,
                        ),
                      ],
                    ),
                  ),
                ),
                if (gastosDelPeriodo.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text('Gastos por categoría', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpace.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        children: [
                          for (final entrada in categoriasOrdenadas)
                            _FilaInforme(
                              nombreCategoriaGasto(entrada.key),
                              formatCurrency(entrada.value),
                            ),
                          const Divider(height: AppSpace.lg),
                          _FilaInforme('Total gastado', formatCurrency(totalGastado), destacado: true),
                        ],
                      ),
                    ),
                  ),
                ],
                if (trabajosDelPeriodo.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Trabajos dados de alta en el periodo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        children: [
                          for (final estado in EstadoTrabajo.values)
                            if (trabajosPorEstado[estado]! > 0)
                              _FilaInforme(
                                nombreEstadoTrabajo(estado),
                                '${trabajosPorEstado[estado]}',
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (presupuestosDelPeriodo.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text('Presupuestos', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpace.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        children: [
                          _FilaInforme('Enviados', '$presupuestosEnviados'),
                          _FilaInforme('Aceptados', '$presupuestosAceptados'),
                          _FilaInforme('Rechazados', '$presupuestosRechazados'),
                          const Divider(height: AppSpace.lg),
                          _FilaInforme(
                            'Tasa de conversión',
                            // "—" en vez de un 0% engañoso cuando todavía
                            // no hay ningún presupuesto decidido en el
                            // periodo -- nunca se inventa una tendencia.
                            tasaConversion == null ? '—' : '${tasaConversion.toStringAsFixed(0)}%',
                            destacado: true,
                          ),
                          if (tasaConversion == null) ...[
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              'Todavía no hay presupuestos aceptados ni rechazados en este '
                              'periodo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (top5Clientes.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  const SectionHeader(title: 'Clientes que más facturan'),
                  const SizedBox(height: AppSpace.sm),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < top5Clientes.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          Builder(
                            builder: (context) {
                              final cliente = widget.appData.clientes.byId(top5Clientes[i].key);
                              return ListTile(
                                title: Text(cliente?.nombre ?? 'Cliente eliminado'),
                                trailing: Text(
                                  formatCurrency(top5Clientes[i].value),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                enabled: cliente != null,
                                onTap: cliente == null
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ClientDetailScreen(
                                            appData: widget.appData,
                                            clienteId: cliente.id,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilaInforme extends StatelessWidget {
  const _FilaInforme(this.label, this.valor, {this.destacado = false, this.positivo});

  final String label;
  final String valor;
  final bool destacado;

  /// Solo se usa cuando [destacado] es true y se quiere colorear según
  /// signo (p.ej. el margen) -- null para un destacado neutro (p.ej. el
  /// total de gastos, que siempre es positivo por construcción).
  final bool? positivo;

  @override
  Widget build(BuildContext context) {
    final color = destacado && positivo != null
        ? (positivo! ? AppColors.success : AppColors.error)
        : null;
    final style = destacado
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: color)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(valor, style: style),
        ],
      ),
    );
  }
}
