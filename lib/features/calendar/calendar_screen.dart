// lib/features/calendar/calendar_screen.dart
//
// Agenda con vista de día y de semana -- navegación por flechas (día o
// semana según la vista activa), botón "Hoy" y una franja de la semana
// actual como indicador/acceso rápido compartido por ambas vistas. Sigue
// sin calendario visual tipo mes: el encargo pide explícitamente no
// añadir uno si no aporta frente a lo que ya hay (sección 2).
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/demo_tag.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_data.dart';
import '../../data/models/cita.dart';
import '../jobs/job_detail_screen.dart';
import 'appointment_form_sheet.dart';

enum _VistaAgenda { dia, semana }

const _diasSemanaCorto = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _diasSemanaLargo = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool _esMismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Lunes de la semana que contiene [d] -- DateTime ya resuelve solo el
/// cambio de mes/año al restar días (p. ej. el lunes de una fecha a
/// principios de enero puede caer en diciembre del año anterior).
DateTime inicioDeSemana(DateTime d) {
  final fecha = _soloFecha(d);
  return fecha.subtract(Duration(days: fecha.weekday - 1));
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _diaSeleccionado = _soloFecha(DateTime.now());
  _VistaAgenda _vista = _VistaAgenda.dia;

  void _irA(DateTime dia) => setState(() => _diaSeleccionado = _soloFecha(dia));

  void _hoy() => _irA(DateTime.now());

  void _anterior() => _irA(
    _diaSeleccionado.subtract(Duration(days: _vista == _VistaAgenda.dia ? 1 : 7)),
  );

  void _siguiente() => _irA(
    _diaSeleccionado.add(Duration(days: _vista == _VistaAgenda.dia ? 1 : 7)),
  );

  String _etiquetaPeriodo() {
    if (_vista == _VistaAgenda.dia) {
      final nombre = _diasSemanaLargo[_diaSeleccionado.weekday - 1];
      return '$nombre, ${formatDate(_diaSeleccionado)}';
    }
    final inicio = inicioDeSemana(_diaSeleccionado);
    final fin = inicio.add(const Duration(days: 6));
    if (inicio.month == fin.month) {
      return '${inicio.day} - ${fin.day} ${_mesCorto(fin.month)} ${fin.year}';
    }
    return '${inicio.day} ${_mesCorto(inicio.month)} - ${fin.day} ${_mesCorto(fin.month)} ${fin.year}';
  }

  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  String _mesCorto(int mes) => _meses[mes - 1];

  @override
  Widget build(BuildContext context) {
    final inicioSemana = inicioDeSemana(_diaSeleccionado);
    final diasSemana = List.generate(
      7,
      (i) => inicioSemana.add(Duration(days: i)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          TextButton(onPressed: _hoy, child: const Text('Hoy')),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              0,
            ),
            child: SegmentedButton<_VistaAgenda>(
              segments: const [
                ButtonSegment(value: _VistaAgenda.dia, label: Text('Día')),
                ButtonSegment(value: _VistaAgenda.semana, label: Text('Semana')),
              ],
              selected: {_vista},
              onSelectionChanged: (seleccion) =>
                  setState(() => _vista = seleccion.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.sm,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _anterior,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: _vista == _VistaAgenda.dia
                      ? 'Día anterior'
                      : 'Semana anterior',
                ),
                Expanded(
                  child: Text(
                    _etiquetaPeriodo(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _siguiente,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: _vista == _VistaAgenda.dia
                      ? 'Día siguiente'
                      : 'Semana siguiente',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              itemCount: diasSemana.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (context, i) {
                final dia = diasSemana[i];
                return _DiaChip(
                  dia: dia,
                  seleccionado: _esMismoDia(dia, _diaSeleccionado),
                  hoy: _esMismoDia(dia, DateTime.now()),
                  onTap: () => _irA(dia),
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
                widget.appData.trabajos,
              ]),
              builder: (context, _) => _vista == _VistaAgenda.dia
                  ? _VistaDia(
                      appData: widget.appData,
                      dia: _diaSeleccionado,
                    )
                  : _VistaSemana(
                      appData: widget.appData,
                      diasSemana: diasSemana,
                      onAbrirDia: (dia) => setState(() {
                        _diaSeleccionado = dia;
                        _vista = _VistaAgenda.dia;
                      }),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VistaDia extends StatelessWidget {
  const _VistaDia({required this.appData, required this.dia});

  final AppData appData;
  final DateTime dia;

  @override
  Widget build(BuildContext context) {
    final citasDelDia = appData.citas.delDia(dia).toList();
    if (citasDelDia.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Sin citas este día',
        message: 'Programa una cita para ${formatDate(dia)}.',
        actionLabel: 'Nueva cita',
        onAction: () => mostrarFormularioCita(
          context,
          appData: appData,
          diaInicial: dia,
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
      itemBuilder: (context, i) =>
          _CitaCard(appData: appData, cita: citasDelDia[i]),
    );
  }
}

class _VistaSemana extends StatelessWidget {
  const _VistaSemana({
    required this.appData,
    required this.diasSemana,
    required this.onAbrirDia,
  });

  final AppData appData;
  final List<DateTime> diasSemana;
  final ValueChanged<DateTime> onAbrirDia;

  @override
  Widget build(BuildContext context) {
    final citasPorDia = [
      for (final dia in diasSemana) appData.citas.delDia(dia).toList(),
    ];
    final totalCitas = citasPorDia.fold<int>(0, (acc, l) => acc + l.length);

    if (totalCitas == 0) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Sin citas esta semana',
        message: 'Toca "+" para programar la primera.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
        AppSpace.lg,
      ),
      children: [
        for (var i = 0; i < diasSemana.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: () => onAbrirDia(diasSemana[i]),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_diasSemanaLargo[diasSemana[i].weekday - 1]}, ${diasSemana[i].day}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _esMismoDia(diasSemana[i], DateTime.now())
                          ? AppColors.primary
                          : null,
                    ),
                  ),
                  if (_esMismoDia(diasSemana[i], DateTime.now())) ...[
                    const SizedBox(width: 6),
                    const _EtiquetaHoy(),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          if (citasPorDia[i].isEmpty)
            Text(
              'Sin citas',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
            )
          else
            for (final cita in citasPorDia[i]) ...[
              _CitaCard(appData: appData, cita: cita, compacta: true),
              const SizedBox(height: AppSpace.sm),
            ],
        ],
      ],
    );
  }
}

class _EtiquetaHoy extends StatelessWidget {
  const _EtiquetaHoy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'HOY',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({
    required this.dia,
    required this.seleccionado,
    required this.hoy,
    required this.onTap,
  });

  final DateTime dia;
  final bool seleccionado;
  final bool hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 46,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: hoy && !seleccionado
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              _diasSemanaCorto[dia.weekday - 1],
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
    required this.appData,
    required this.cita,
    this.compacta = false,
  });

  final AppData appData;
  final Cita cita;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final cliente = cita.clienteId != null
        ? appData.clientes.byId(cita.clienteId!)
        : null;
    // Si el trabajo se borró después de programar la cita, trabajo queda
    // null y sencillamente no se muestra esa línea -- sin excepción.
    final trabajo = cita.trabajoId != null
        ? appData.trabajos.byId(cita.trabajoId!)
        : null;

    return Card(
      child: InkWell(
        onTap: () => mostrarFormularioCita(
          context,
          appData: appData,
          existente: cita,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.all(compacta ? AppSpace.sm + 4 : AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Container(
                width: 1,
                height: compacta ? 32 : 44,
                color: AppColors.border,
                margin: const EdgeInsets.only(top: 2),
              ),
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
                    if (cliente != null)
                      Text(
                        cliente.nombre,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (trabajo != null)
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(
                              appData: appData,
                              trabajoId: trabajo.id,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.build_outlined,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                trabajo.titulo,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!compacta &&
                        cita.notas != null &&
                        cita.notas!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          cita.notas!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
                onPressed: () => appData.citas.update(
                  cita.copyWith(completada: !cita.completada),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
