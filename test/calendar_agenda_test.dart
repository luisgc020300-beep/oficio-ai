// test/calendar_agenda_test.dart
//
// Agenda: vista de día/semana, navegación entre fechas (incluido cambio
// de mes y año), orden cronológico, cita -> trabajo, trabajo eliminado
// sin romper la app (encargo iteración 4, sección 7, puntos 1-7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/calendar/calendar_screen.dart';
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

  group('inicioDeSemana() -- cambio de mes y año', () {
    test('un miércoles cualquiera devuelve el lunes de esa semana', () {
      // 2026-02-18 es miércoles.
      final inicio = inicioDeSemana(DateTime(2026, 2, 18));
      expect(inicio, DateTime(2026, 2, 16)); // lunes
    });

    test('ya en lunes, devuelve el mismo día', () {
      final lunes = DateTime(2026, 2, 16);
      expect(inicioDeSemana(lunes), lunes);
    });

    test('cruza el cambio de mes correctamente', () {
      // 2026-03-02 es lunes; el domingo anterior sería 2026-03-01, así
      // que el lunes de esa semana cae en marzo, no en febrero.
      expect(inicioDeSemana(DateTime(2026, 3, 2)), DateTime(2026, 3, 2));
      // 2026-03-03 es martes -> el lunes es el 2 de marzo.
      expect(inicioDeSemana(DateTime(2026, 3, 3)), DateTime(2026, 3, 2));
      // Caso real de cambio de mes: 2026-02-02 es lunes; el 2026-02-01
      // (domingo) pertenece a la semana ANTERIOR, que empieza en enero.
      expect(inicioDeSemana(DateTime(2026, 2, 1)), DateTime(2026, 1, 26));
    });

    test('cruza el cambio de año correctamente', () {
      // 2026-01-01 es jueves -> el lunes de esa semana es 2025-12-29.
      expect(inicioDeSemana(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });
  });

  group('1 y 4. Vista de día muestra las citas del día seleccionado, en orden', () {
    testWidgets('solo las citas de hoy aparecen, ordenadas por hora', (
      tester,
    ) async {
      final appData = await _appDataVacia();
      final hoy = DateTime.now();
      await appData.citas.add(
        Cita(
          id: 'c1',
          titulo: 'Tarde',
          fechaHora: DateTime(hoy.year, hoy.month, hoy.day, 17),
        ),
      );
      await appData.citas.add(
        Cita(
          id: 'c2',
          titulo: 'Mañana',
          fechaHora: DateTime(hoy.year, hoy.month, hoy.day, 9),
        ),
      );
      await appData.citas.add(
        Cita(
          id: 'c3',
          titulo: 'Otro día',
          fechaHora: hoy.add(const Duration(days: 5)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('Tarde'), findsOneWidget);
      expect(find.text('Otro día'), findsNothing);

      // "Mañana" (9h) debe quedar antes que "Tarde" (17h) en la lista.
      final posicionManana = tester.getTopLeft(find.text('Mañana')).dy;
      final posicionTarde = tester.getTopLeft(find.text('Tarde')).dy;
      expect(posicionManana, lessThan(posicionTarde));
    });
  });

  group('2. Vista de semana muestra las citas de la semana correcta', () {
    testWidgets('cambiar a la vista de semana agrupa por día', (tester) async {
      final appData = await _appDataVacia();
      final lunes = inicioDeSemana(DateTime.now());
      await appData.citas.add(
        Cita(id: 'c1', titulo: 'Reunión lunes', fechaHora: lunes.add(const Duration(hours: 10))),
      );
      await appData.citas.add(
        Cita(
          id: 'c2',
          titulo: 'Fuera de semana',
          fechaHora: lunes.subtract(const Duration(days: 3)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();

      expect(find.text('Reunión lunes'), findsOneWidget);
      expect(find.text('Fuera de semana'), findsNothing);
    });
  });

  group('3. Navegación entre fechas', () {
    testWidgets('la flecha siguiente en vista de día avanza un día', (
      tester,
    ) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      final manana = DateTime.now().add(const Duration(days: 1));
      final etiquetaHoy = find.textContaining(
        inicioDeSemana(DateTime.now()).day.toString(),
      );
      expect(etiquetaHoy, findsWidgets); // sanity: la franja pinta algo

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.textContaining('${manana.day}'), findsWidgets);
    });

    testWidgets('"Hoy" vuelve a la fecha actual tras navegar', (tester) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();

      final hoy = DateTime.now();
      expect(find.textContaining('${hoy.day}'), findsWidgets);
    });
  });

  group('6 y 7. Cita vinculada a un trabajo', () {
    testWidgets('abre el trabajo asociado si todavía existe', (tester) async {
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
      final hoy = DateTime.now();
      await appData.citas.add(
        Cita(
          id: 'cita1',
          titulo: 'Visita',
          fechaHora: DateTime(hoy.year, hoy.month, hoy.day, 10),
          clienteId: 'c1',
          trabajoId: 't1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambio de grifo'), findsOneWidget);
      await tester.tap(find.text('Cambio de grifo'));
      await tester.pumpAndSettle();

      expect(find.text('Este trabajo ya no existe.'), findsNothing);
      expect(find.text('Citas programadas'), findsOneWidget); // ficha del trabajo
    });

    testWidgets('no rompe la app si el trabajo asociado ya no existe', (
      tester,
    ) async {
      final appData = await _appDataVacia();
      final hoy = DateTime.now();
      await appData.citas.add(
        Cita(
          id: 'cita1',
          titulo: 'Visita huérfana',
          fechaHora: DateTime(hoy.year, hoy.month, hoy.day, 10),
          trabajoId: 'trabajo-que-no-existe',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      // No lanza excepción y la cita se sigue viendo con normalidad,
      // simplemente sin la línea de trabajo asociado.
      expect(tester.takeException(), isNull);
      expect(find.text('Visita huérfana'), findsOneWidget);
    });
  });

  group('5. Crear y editar citas persiste correctamente', () {
    testWidgets('crear una cita desde la agenda aparece inmediatamente', (
      tester,
    ) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(appData: appData)),
      );
      await tester.pumpAndSettle();

      // Sin citas todavía, el estado vacío también tiene un botón con
      // Icons.add -- hay que apuntar al FAB en concreto, no al icono.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Título *'), 'Revisión caldera');
      await tester.tap(find.text('Crear cita'));
      await tester.pumpAndSettle();

      expect(appData.citas.citas, hasLength(1));
      expect(find.text('Revisión caldera'), findsOneWidget);
    });
  });
}
