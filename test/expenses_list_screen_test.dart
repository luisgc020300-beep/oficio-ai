// test/expenses_list_screen_test.dart
//
// Flujo de la pantalla de gastos dirigido por la interfaz: estado
// vacío, crear, filtrar por categoría, y anular con confirmación y
// motivo obligatorio (encargo iteración 9, secciones 3 y 6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/core/utils/formatters.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/gasto.dart';
import 'package:oficio_ai/features/expenses/expenses_list_screen.dart';
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
    appData.facturas.load(),
    appData.gastos.load(),
  ]);
  return appData;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets('sin gastos todavía, muestra el estado vacío con acción', (tester) async {
    final appData = await _appDataVacia();
    await tester.pumpWidget(MaterialApp(home: ExpensesListScreen(appData: appData)));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay gastos'), findsOneWidget);
    expect(find.text('Nuevo gasto'), findsOneWidget);
  });

  testWidgets(
    'crear un gasto desde el FAB lo añade a la lista y al total del mes',
    (tester) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(MaterialApp(home: ExpensesListScreen(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción *'),
        'Tubos de cobre',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Importe (€) *'), '35.50');
      // El formulario tiene bastantes más campos que, p. ej., el de
      // trabajo -- el botón de guardar puede quedar fuera de la parte
      // visible del SingleChildScrollView de la hoja hasta
      // desplazarse hasta él.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Registrar gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar gasto'));
      await tester.pumpAndSettle();

      expect(appData.gastos.gastos, hasLength(1));
      expect(appData.gastos.gastos.first.descripcion, 'Tubos de cobre');
      expect(appData.gastos.gastos.first.importe, 35.5);
      expect(find.text('Tubos de cobre'), findsOneWidget);
      expect(find.text(formatCurrency(35.5)), findsWidgets); // en la fila y en el total
    },
  );

  testWidgets(
    'el formulario rechaza un importe de cero o inválido y no crea nada',
    (tester) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(MaterialApp(home: ExpensesListScreen(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción *'), 'Gasto inválido');
      await tester.enterText(find.widgetWithText(TextFormField, 'Importe (€) *'), '0');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Registrar gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar gasto'));
      await tester.pumpAndSettle();

      expect(appData.gastos.gastos, isEmpty);
      expect(find.text('Debe ser mayor que cero'), findsOneWidget);
    },
  );

  testWidgets(
    'el filtro de categoría solo muestra los gastos de esa categoría',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.gastos.add(
        Gasto(
          id: 'g1',
          descripcion: 'Tubería',
          importe: 20,
          fecha: DateTime.now(),
          categoria: CategoriaGasto.materiales,
          creadoEl: DateTime.now(),
        ),
      );
      await appData.gastos.add(
        Gasto(
          id: 'g2',
          descripcion: 'Gasolina',
          importe: 15,
          fecha: DateTime.now(),
          categoria: CategoriaGasto.desplazamiento,
          creadoEl: DateTime.now(),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: ExpensesListScreen(appData: appData)));
      await tester.pumpAndSettle();

      expect(find.text('Tubería'), findsOneWidget);
      expect(find.text('Gasolina'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Desplazamiento'));
      await tester.pumpAndSettle();

      expect(find.text('Tubería'), findsNothing);
      expect(find.text('Gasolina'), findsOneWidget);
    },
  );

  testWidgets(
    'anular un gasto exige motivo, con confirmación, y deja de contar '
    'en el total sin desaparecer de la lista',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.gastos.add(
        Gasto(
          id: 'g1',
          descripcion: 'Material a anular',
          importe: 50,
          fecha: DateTime.now(),
          creadoEl: DateTime.now(),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: ExpensesListScreen(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      // Sin motivo, "Anular" en el diálogo no debe anular nada.
      await tester.tap(find.widgetWithText(FilledButton, 'Anular'));
      await tester.pumpAndSettle();
      expect(appData.gastos.byId('g1')!.estado, EstadoGasto.activo);

      // Reabre y esta vez rellena el motivo.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Motivo *'), 'Duplicado por error');
      await tester.tap(find.widgetWithText(FilledButton, 'Anular'));
      await tester.pumpAndSettle();

      expect(appData.gastos.byId('g1')!.estado, EstadoGasto.anulado);
      expect(appData.gastos.byId('g1')!.motivoAnulacion, 'Duplicado por error');
      // Sigue en la lista (no se esconde el rastro) -- su propia fila
      // todavía muestra "50,00 €", solo que tachado (ver
      // expenses_list_screen.dart); lo que cambia es el TOTAL, que deja
      // de contarlo.
      expect(find.text('Material a anular'), findsOneWidget);
      expect(find.text(formatCurrency(0)), findsWidgets); // el total ahora es 0
    },
  );
}
