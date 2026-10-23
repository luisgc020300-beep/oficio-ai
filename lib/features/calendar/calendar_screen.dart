// lib/features/calendar/calendar_screen.dart
//
// Agenda simple por días -- franja horizontal de fechas (hoy + 13 días) y
// debajo las citas de ese día ordenadas por hora. Suficiente para una
// demo; un calendario mensual completo queda fuera de alcance del
// prototipo (ver README).
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/cita.dart';
import 'appointment_form_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _diaSeleccionado = DateTime.now();

  bool _esMismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dias = List.generate(
      14,
      (i) => DateTime.now().add(Duration(days: i)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostrarFormularioCita(
          context,
          appData: widget.appData,
          diaInicial: _diaSeleccionado,
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              itemCount: dias.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (context, i) {
                final dia = dias[i];
                final seleccionado = _esMismoDia(dia, _diaSeleccionado);
                return _DiaChip(
                  dia: dia,
                  seleccionado: seleccionado,
                  onTap: () => setState(() => _diaSeleccionado = dia),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.appData.citas,
                widget.appData.clientes,
              ]),
              builder: (context, _) {
                final citasDelDia = widget.appData.citas
                    .delDia(_diaSeleccionado)
                    .toList();
                if (citasDelDia.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Sin citas este día',
                    message: 'Programa una cita para ${formatDate(_diaSeleccionado)}.',
                    actionLabel: 'Nueva cita',
                    onAction: () => mostrarFormularioCita(
                      context,
                      appData: widget.appData,
                      diaInicial: _diaSeleccionado,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.lg,
                  ),
                  itemCount: citasDelDia.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, i) {
                    final cita = citasDelDia[i];
                    final cliente = cita.clienteId != null
                        ? widget.appData.clientes.byId(cita.clienteId!)
                        : null;
                    return _CitaCard(
                      cita: cita,
                      nombreCliente: cliente?.nombre,
                      onTap: () => mostrarFormularioCita(
                        context,
                        appData: widget.appData,
                        existente: cita,
                      ),
                      onCompletar: () => widget.appData.citas.update(
                        cita.copyWith(completada: !cita.completada),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({
    required this.dia,
    required this.seleccionado,
    required this.onTap,
  });

  final DateTime dia;
  final bool seleccionado;
  final VoidCallback onTap;

  static const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 46,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              _diasSemana[dia.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: seleccionado ? Colors.white70 : AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${dia.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: seleccionado ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitaCard extends StatelessWidget {
  const _CitaCard({
    required this.cita,
    required this.nombreCliente,
    required this.onTap,
    required this.onCompletar,
  });

  final Cita cita;
  final String? nombreCliente;
  final VoidCallback onTap;
  final VoidCallback onCompletar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTime(cita.fechaHora),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      formatTime(cita.fin),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              const SizedBox(width: AppSpace.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cita.titulo,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  decoration: cita.completada
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: cita.completada
                                      ? AppColors.inkFaint
                                      : null,
                                ),
                          ),
                        ),
                        if (cita.esDemo) ...[
                          const SizedBox(width: 6),
                          const DemoTag(),
                        ],
                      ],
                    ),
                    if (nombreCliente != null)
                      Text(
                        nombreCliente!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  cita.completada
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: cita.completada
                      ? AppColors.success
                      : AppColors.inkFaint,
                ),
                onPressed: onCompletar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
