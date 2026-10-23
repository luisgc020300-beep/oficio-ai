// test/jobs_estado_filtro_busqueda_test.dart
//
// Cambio de estado desde la ficha del trabajo, filtros, búsqueda y su
// combinación en el listado (encargo iteración 4, sección 7, puntos
// 8-11, 13-15).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/jobs/job_detail_screen.dart';
import 'package:oficio_ai/features/jobs/jobs_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppData> _appDataVacia() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final appData = AppData(store);
  await Future.wait([
    appData.clientes.load(),
    appData.trabajos.load(),
    appData.presupuestos.load(),
    appData.citas.load(),
  ]);
  return appData;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('8. Cambiar el estado desde la ficha', () {
    testWidgets('pendiente -> en curso sin confirmación, se refleja al momento', (
      tester,
    ) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Ana', creadoEl: DateTime(2026)),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(appData: appData, trabajoId: 't1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pendiente'), findsOneWidget);
      await tester.tap(find.text('Empezar trabajo'));
      await tester.pumpAndSettle();

      expect(appData.trabajos.byId('t1')!.estado, EstadoTrabajo.enCurso);
      expect(find.text('En curso'), findsOneWidget);
    });

    testWidgets('en curso -> terminado pide confirmación', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Ana', creadoEl: DateTime(2026)),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.enCurso,
          creadoEl: DateTime(2026),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(appData: appData, trabajoId: 't1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marcar como terminado'));
      await tester.pumpAndSettle();

      expect(find.text('¿Marcar como terminado?'), findsOneWidget);
      // Todavía no se ha aplicado -- sigue en curso hasta confirmar.
      expect(appData.trabajos.byId('t1')!.estado, EstadoTrabajo.enCurso);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(appData.trabajos.byId('t1')!.estado, EstadoTrabajo.finalizado);
    });

    test('cambiar el estado no toca el presupuesto ni las citas', () async {
      final appData = await _appDataVacia();
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p1',
          clienteId: 'c1',
          titulo: 'Presupuesto',
          conceptos: const [],
          estado: EstadoPresupuesto.aceptado,
          creadoEl: DateTime(2026),
        ),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026),
          presupuestoId: 'p1',
        ),
      );

      await appData.trabajos.update(
        appData.trabajos.byId('t1')!.copyWith(estado: EstadoTrabajo.enCurso),
      );

      expect(appData.presupuestos.byId('p1')!.estado, EstadoPresupuesto.aceptado);
    });
  });

  group('9, 10 y 11. Filtro por estado, búsqueda y su combinación', () {
    Future<AppData> datosDePrueba() async {
      final appData = await _appDataVacia();
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
      );
      await appData.clientes.add(
        Cliente(id: 'c2', nombre: 'Luis Gómez', creadoEl: DateTime(2026)),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't2',
          clienteId: 'c2',
          titulo: 'Revisión eléctrica',
          estado: EstadoTrabajo.enCurso,
          creadoEl: DateTime(2026, 1, 2),
        ),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't3',
          clienteId: 'c1',
          titulo: 'Instalación de termo',
          estado: EstadoTrabajo.enCurso,
          creadoEl: DateTime(2026, 1, 3),
        ),
      );
      return appData;
    }

    testWidgets('el filtro "En curso" solo muestra trabajos en ese estado', (
      tester,
    ) async {
      final appData = await datosDePrueba();
      await tester.pumpWidget(
        MaterialApp(home: JobsListScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('En curso'));
      await tester.pumpAndSettle();

      expect(find.text('Cambio de grifo'), findsNothing);
      expect(find.text('Revisión eléctrica'), findsOneWidget);
      expect(find.text('Instalación de termo'), findsOneWidget);
    });

    testWidgets('la búsqueda por nombre de cliente filtra la lista', (
      tester,
    ) async {
      final appData = await datosDePrueba();
      await tester.pumpWidget(
        MaterialApp(home: JobsListScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por cliente o descripción...'),
        'gómez',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambio de grifo'), findsNothing);
      expect(find.text('Instalación de termo'), findsNothing);
      expect(find.text('Revisión eléctrica'), findsOneWidget);
    });

    testWidgets('búsqueda + filtro combinados reducen más que cada uno por separado', (
      tester,
    ) async {
      final appData = await datosDePrueba();
      await tester.pumpWidget(
        MaterialApp(home: JobsListScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('En curso'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por cliente o descripción...'),
        'ana',
      );
      await tester.pumpAndSettle();

      // Solo "Instalación de termo" es de Ana Pérez Y está en curso.
      expect(find.text('Instalación de termo'), findsOneWidget);
      expect(find.text('Revisión eléctrica'), findsNothing);
      expect(find.text('Cambio de grifo'), findsNothing);
    });

    testWidgets('sin resultados muestra el estado vacío', (tester) async {
      final appData = await datosDePrueba();
      await tester.pumpWidget(
        MaterialApp(home: JobsListScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por cliente o descripción...'),
        'nadie-coincide-con-esto',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
    });
  });
}
