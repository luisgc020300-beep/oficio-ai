// test/dashboard_hoy_test.dart
//
// Sección "Hoy" del dashboard -- no debe duplicar lo que ya muestra
// "Próximas citas" (encargo iteración 4, secciones 4 y 7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/features/dashboard/dashboard_screen.dart';
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

  testWidgets(
    '"Hoy" muestra la cita de hoy; "Próximas citas" muestra solo la futura, sin duplicar',
    (tester) async {
      final appData = await _appDataVacia();
      final hoy = DateTime.now();
      await appData.citas.add(
        Cita(
          id: 'hoy',
          titulo: 'Visita de hoy',
          fechaHora: DateTime(hoy.year, hoy.month, hoy.day, 16),
        ),
      );
      await appData.citas.add(
        Cita(
          id: 'futura',
          titulo: 'Visita futura',
          fechaHora: hoy.add(const Duration(days: 3)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            appData: appData,
            onVerTrabajos: () {},
            onVerPresupuestos: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Visita de hoy'), findsOneWidget);

      // "Próximas citas" está más abajo del scroll -- hay que desplazarse
      // hasta que aparezca antes de buscarla.
      await tester.scrollUntilVisible(
        find.text('Visita futura'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Visita futura'), findsOneWidget);

      // La cita de hoy no debe repetirse también dentro de "Próximas
      // citas": al estar ya desplazados hasta esa sección, si "Visita de
      // hoy" hubiera duplicado ahí, aparecería junto a "Visita futura".
      expect(find.text('Visita de hoy'), findsNothing);
    },
  );

  testWidgets('sin citas hoy, muestra el estado vacío con acción', (
    tester,
  ) async {
    final appData = await _appDataVacia();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          appData: appData,
          onVerTrabajos: () {},
          onVerPresupuestos: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin citas programadas para hoy.'), findsOneWidget);
    expect(find.text('Programar cita'), findsOneWidget);
  });
}
