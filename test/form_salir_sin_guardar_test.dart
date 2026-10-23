// test/form_salir_sin_guardar_test.dart
//
// Regresión del bug de iteración 6.1: en quote_form_screen.dart e
// invoice_form_screen.dart, el campo "Título" marcaba _tocado = true
// SIN pasar por setState(), así que PopScope(canPop: !_tocado, ...) se
// quedaba con el valor construido en el último build (antes del
// cambio) y el formulario se podía cerrar sin avisar si el título era
// el ÚNICO campo tocado -- el resto de campos (cliente, conceptos,
// IVA, descuento) ya llamaban a setState() correctamente y por eso el
// bug no se veía con cualquier edición, solo con esa concreta.
//
// Cubre, para ambos formularios: abrir y salir sin tocar nada (sin
// diálogo), tocar y pedir volver (con diálogo), "Seguir editando"
// conserva los datos, "Descartar" sale sin persistir, guardar y salir
// no muestra diálogo, los datos guardados se conservan, y un segundo
// intento de navegación no apila un segundo diálogo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/features/invoices/invoice_form_screen.dart';
import 'package:oficio_ai/features/quotes/quote_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppData> _appDataConCliente() async {
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
  await appData.clientes.add(
    Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
  );
  return appData;
}

/// Empuja [pantalla] sobre una Scaffold base, para poder usar
/// pageBack()/el botón "atrás" real del AppBar, igual que en la app.
Future<void> _abrir(WidgetTester tester, Widget pantalla) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => pantalla),
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
}

void main() {
  group('QuoteFormScreen', () {
    testWidgets('abrir y volver sin tocar nada no muestra confirmación', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(QuoteFormScreen), findsNothing); // ya ha salido
    });

    testWidgets(
      'tocar SOLO el título y pedir volver muestra la confirmación '
      '(regresión del bug: antes no se veía con este campo)',
      (tester) async {
        final appData = await _appDataConCliente();
        await _abrir(
          tester,
          QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'Título *'),
          'Reforma baño',
        );
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        // No ha salido todavía -- el diálogo intercepta la navegación.
        expect(find.byType(QuoteFormScreen), findsOneWidget);
      },
    );

    testWidgets('"Seguir editando" cierra el diálogo y conserva lo escrito', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Reforma baño',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(QuoteFormScreen), findsOneWidget);
      expect(find.text('Reforma baño'), findsOneWidget);
    });

    testWidgets('"Descartar" permite salir y no persiste nada', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Reforma baño',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(QuoteFormScreen), findsNothing);
      expect(appData.presupuestos.presupuestos, isEmpty);
    });

    testWidgets('guardar correctamente y salir no muestra confirmación, '
        'y lo guardado se conserva', (tester) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Reforma baño',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción'),
        'Alicatado',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear presupuesto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // El propio guardado ya navega fuera -- sin diálogo de descarte.
      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(QuoteFormScreen), findsNothing);
      expect(appData.presupuestos.presupuestos, hasLength(1));
      expect(appData.presupuestos.presupuestos.first.titulo, 'Reforma baño');
    });

    testWidgets(
      'dos intentos de volver seguidos no apilan dos confirmaciones',
      (tester) async {
        final appData = await _appDataConCliente();
        await _abrir(
          tester,
          QuoteFormScreen(appData: appData, clienteIdFijo: 'c1'),
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'Título *'),
          'Reforma baño',
        );
        await tester.pumpAndSettle();

        // Dos intentos de pop seguidos, sin esperar a que el primero
        // termine de abrir el diálogo -- tester.pageBack() es un método
        // "guardado" por TestAsyncUtils y no admite dos llamadas
        // solapadas, así que se dispara directamente sobre el
        // NavigatorState, que es como PopScope recibe el intento real
        // tanto del botón de la AppBar como del gesto/botón del sistema.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.maybePop());
        unawaited(navigator.maybePop());
        await tester.pumpAndSettle();

        // findsOneWidget ya descarta por sí solo que haya dos diálogos
        // apilados (si los hubiera, habría dos coincidencias de texto).
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      },
    );
  });

  group('InvoiceFormScreen', () {
    testWidgets('abrir y volver sin tocar nada no muestra confirmación', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(InvoiceFormScreen), findsNothing);
    });

    testWidgets(
      'tocar SOLO el título y pedir volver muestra la confirmación '
      '(regresión del bug: antes no se veía con este campo)',
      (tester) async {
        final appData = await _appDataConCliente();
        await _abrir(
          tester,
          InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'Título *'),
          'Factura reforma baño',
        );
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        expect(find.byType(InvoiceFormScreen), findsOneWidget);
      },
    );

    testWidgets('"Seguir editando" cierra el diálogo y conserva lo escrito', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Factura reforma baño',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(InvoiceFormScreen), findsOneWidget);
      expect(find.text('Factura reforma baño'), findsOneWidget);
    });

    testWidgets('"Descartar" permite salir y no persiste nada', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Factura reforma baño',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(InvoiceFormScreen), findsNothing);
      expect(appData.facturas.facturas, isEmpty);
    });

    testWidgets('guardar correctamente y salir no muestra confirmación, '
        'y lo guardado se conserva', (tester) async {
      final appData = await _appDataConCliente();
      await _abrir(
        tester,
        InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Título *'),
        'Factura reforma baño',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción'),
        'Alicatado',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(InvoiceFormScreen), findsNothing);
      expect(appData.facturas.facturas, hasLength(1));
      expect(appData.facturas.facturas.first.titulo, 'Factura reforma baño');
      // La protección de facturas emitidas/numeración no se ha tocado:
      // sigue siendo un borrador sin número.
      expect(appData.facturas.facturas.first.numero, isNull);
    });

    testWidgets(
      'dos intentos de volver seguidos no apilan dos confirmaciones',
      (tester) async {
        final appData = await _appDataConCliente();
        await _abrir(
          tester,
          InvoiceFormScreen(appData: appData, clienteIdFijo: 'c1'),
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'Título *'),
          'Factura reforma baño',
        );
        await tester.pumpAndSettle();

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.maybePop());
        unawaited(navigator.maybePop());
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      },
    );
  });
}
