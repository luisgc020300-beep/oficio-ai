// test/business_settings_screen_test.dart
//
// Pantalla "Mi negocio": estado inicial vacío, guardar persiste y se ve
// reflejado, validación de formato junto al campo, confirmación al
// salir con cambios sin guardar, y acceso desde el dashboard (encargo
// iteración 6, secciones 9 y 10).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/features/dashboard/dashboard_screen.dart';
import 'package:oficio_ai/features/settings/business_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El formulario de "Mi negocio" es un ListView largo -- Flutter solo
/// materializa lo cercano al viewport (mismo motivo que en
/// calendar_agenda_test.dart). En vez de desplazarse campo a campo, se
/// agranda el viewport del test para que quepa entero de una vez.
void _agrandarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppData> _appDataVacia() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final appData = AppData(store);
  await Future.wait([
    appData.clientes.load(),
    appData.trabajos.load(),
    appData.presupuestos.load(),
    appData.citas.load(),
    appData.facturas.load(),
    appData.negocio.load(),
  ]);
  return appData;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets('estado inicial sin datos: muestra el aviso y campos vacíos', (
    tester,
  ) async {
    _agrandarViewport(tester);
    final appData = await _appDataVacia();
    await tester.pumpWidget(
      MaterialApp(home: BusinessSettingsScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Todavía no has configurado los datos'),
      findsOneWidget,
    );
    expect(find.text('España'), findsOneWidget); // país por defecto
  });

  testWidgets('rellenar y guardar persiste en el repositorio y lo '
      'confirma en pantalla', (tester) async {
    _agrandarViewport(tester);
    final appData = await _appDataVacia();
    await tester.pumpWidget(
      MaterialApp(home: BusinessSettingsScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre y apellidos *'),
      'Juan Pérez García',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'NIF/CIF *'), '12345678Z');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dirección *'),
      'Calle Mayor 1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código postal *'),
      '28001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Localidad *'), 'Madrid');
    await tester.enterText(find.widgetWithText(TextFormField, 'Provincia *'), 'Madrid');

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Datos guardados.'), findsOneWidget);
    expect(appData.negocio.datos, isNotNull);
    expect(appData.negocio.datos!.nombreFiscal, 'Juan Pérez García');
    expect(appData.negocio.datos!.listoParaFacturar, isTrue);
  });

  testWidgets('un NIF con formato inválido muestra el error junto al '
      'campo y no deja guardar', (tester) async {
    _agrandarViewport(tester);
    final appData = await _appDataVacia();
    await tester.pumpWidget(
      MaterialApp(home: BusinessSettingsScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre y apellidos *'),
      'Juan Pérez',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'NIF/CIF *'), '12345678A');

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no coincide con el número'), findsOneWidget);
    expect(appData.negocio.datos, isNull);
  });

  testWidgets('salir con cambios sin guardar pide confirmación', (tester) async {
    _agrandarViewport(tester);
    final appData = await _appDataVacia();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessSettingsScreen(appData: appData),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre y apellidos *'),
      'Juan',
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    // Sigue en la pantalla de "Mi negocio" -- no ha salido todavía.
    expect(find.byType(BusinessSettingsScreen), findsOneWidget);
  });

  testWidgets(
    'dos intentos de volver seguidos no apilan dos confirmaciones '
    '(iteración 6.1)',
    (tester) async {
      _agrandarViewport(tester);
      final appData = await _appDataVacia();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessSettingsScreen(appData: appData),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre y apellidos *'),
        'Juan',
      );
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      unawaited(navigator.maybePop());
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    },
  );

  testWidgets('el icono de "Mi negocio" en el dashboard abre la pantalla', (
    tester,
  ) async {
    final appData = await _appDataVacia();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          appData: appData,
          onVerTrabajos: () {},
          onVerPresupuestos: () {},
          onVerFacturas: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mi negocio'));
    await tester.pumpAndSettle();

    expect(find.byType(BusinessSettingsScreen), findsOneWidget);
  });
}
