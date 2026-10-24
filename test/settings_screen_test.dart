// test/settings_screen_test.dart
//
// Ajustes: el icono de engranaje del dashboard la abre, el interruptor
// de modo oscuro cambia el tema de verdad (no solo el widget de la
// fila), y "Cerrar sesión" exige confirmación antes de borrar los datos
// del dispositivo -- cancelar no debe tocar nada.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/core/theme/app_colors.dart';
import 'package:oficio_ai/core/theme/theme_controller.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppData, ThemeController)> _arrancar() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final appData = AppData(store);
  await Future.wait([
    appData.clientes.load(),
    appData.trabajos.load(),
    appData.presupuestos.load(),
    appData.citas.load(),
    appData.facturas.load(),
    appData.gastos.load(),
    appData.negocio.load(),
  ]);
  return (appData, ThemeController(store));
}

Widget _envolver(AppData appData, ThemeController themeController) => MaterialApp(
  home: DashboardScreen(
    appData: appData,
    themeController: themeController,
    onVerTrabajos: () {},
    onVerPresupuestos: () {},
    onVerFacturas: () {},
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  // AppColors guarda el modo en una variable estática en memoria (ver
  // AppColors.actualizar()) -- sin resetearla, un test que active el
  // modo oscuro dejaría la app en oscuro para el siguiente test de este
  // mismo archivo.
  setUp(() => AppColors.actualizar(AppAppearance.claro));

  testWidgets(
    'el icono de ajustes del dashboard abre Ajustes con modo oscuro, Mi negocio y cerrar sesión',
    (tester) async {
      final (appData, themeController) = await _arrancar();
      await tester.pumpWidget(_envolver(appData, themeController));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Modo oscuro'), findsOneWidget);
      expect(find.text('Mi negocio'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    },
  );

  testWidgets('activar el interruptor de modo oscuro cambia el tema de verdad', (tester) async {
    final (appData, themeController) = await _arrancar();
    expect(themeController.oscuro, isFalse);

    await tester.pumpWidget(_envolver(appData, themeController));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    expect(themeController.oscuro, isTrue);
    expect(AppColors.esOscuro, isTrue);
    expect(AppColors.background, const Color(0xFF0A0A0C));

    // El texto de las filas Cupertino (CupertinoListTile) resuelve su
    // color por el *brillo* ambiental, no por nuestro AppColors -- sin
    // envolverlas en un CupertinoTheme con el brillo correcto, se quedan
    // leyendo el brillo del sistema operativo (que en este test sigue en
    // claro) y el texto se vuelve ilegible sobre el fondo ya oscuro. Esto
    // comprueba que sí se propaga el brillo oscuro.
    final cupertinoTheme = CupertinoTheme.of(
      tester.element(find.byType(CupertinoListSection).first),
    );
    expect(cupertinoTheme.brightness, Brightness.dark);

    // Vuelve a Inicio: el Scaffold debe pintarse ya con el fondo oscuro
    // (no solo el estado del controlador) -- confirma que todo el árbol
    // se reconstruyó con el tema nuevo, no solo la pantalla de Ajustes.
    await tester.pageBack();
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, isNot(const Color(0xFFF6F7F9)));
  });

  testWidgets(
    'cerrar sesión exige confirmación -- cancelar no borra nada, confirmar borra los datos del dispositivo',
    (tester) async {
      final (appData, themeController) = await _arrancar();
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Cliente de prueba', creadoEl: DateTime.now()),
      );
      expect(appData.clientes.byId('c1'), isNotNull);

      await tester.pumpWidget(_envolver(appData, themeController));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar sesión').first);
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(appData.clientes.byId('c1'), isNotNull);

      await tester.tap(find.text('Cerrar sesión').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Cerrar sesión')),
      );
      await tester.pumpAndSettle();

      expect(appData.clientes.byId('c1'), isNull);
      // Vuelve a Inicio (como si acabaras de reinstalar) en vez de
      // quedarse en Ajustes.
      expect(find.text('Ajustes'), findsNothing);
    },
  );
}
