// test/invoices_list_screen_test.dart
//
// Búsqueda, filtro por estado e identificación de vencidas en el
// listado de facturas, y su estado vacío (encargo iteración 5, sección
// 12, puntos 13, 14, 17 y 20).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/features/invoices/invoices_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Future<AppData> _appDataConClientes() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final appData = AppData(store);
  await Future.wait([
    appData.clientes.load(),
    appData.trabajos.load(),
    appData.presupuestos.load(),
    appData.citas.load(),
    appData.facturas.load(),
  ]);
  await appData.clientes.add(
    Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
  );
  await appData.clientes.add(
    Cliente(id: 'c2', nombre: 'Luis Gómez', creadoEl: DateTime(2026)),
  );
  return appData;
}

Factura _borrador(String id, String clienteId, String titulo) => Factura(
  id: id,
  clienteId: clienteId,
  titulo: titulo,
  conceptos: const [
    ConceptoPresupuesto(
      id: 'c1',
      descripcion: 'Servicio',
      cantidad: 1,
      precioUnitario: 50,
    ),
  ],
  creadaEl: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets('sin facturas todavía, muestra el estado vacío con acción', (
    tester,
  ) async {
    final appData = await _appDataConClientes();
    await tester.pumpWidget(
      MaterialApp(home: InvoicesListScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay facturas'), findsOneWidget);
    expect(find.text('Nueva factura'), findsOneWidget);
  });

  testWidgets('la búsqueda filtra por nombre de cliente', (tester) async {
    final appData = await _appDataConClientes();
    await appData.facturas.add(_borrador('f1', 'c1', 'Factura de Ana'));
    await appData.facturas.add(_borrador('f2', 'c2', 'Factura de Luis'));

    await tester.pumpWidget(
      MaterialApp(home: InvoicesListScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Factura de Ana'), findsOneWidget);
    expect(find.textContaining('Factura de Luis'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Luis');
    await tester.pumpAndSettle();

    expect(find.textContaining('Factura de Luis'), findsOneWidget);
    expect(find.textContaining('Factura de Ana'), findsNothing);
  });

  testWidgets('el filtro "Vencidas" muestra solo facturas emitidas sin '
      'cobrar cuya fecha de vencimiento ya pasó', (tester) async {
    final appData = await _appDataConClientes();
    await appData.facturas.add(_borrador('f1', 'c1', 'Al día'));
    await appData.facturas.emitir(
      'f1',
      fechaVencimiento: DateTime.now().add(const Duration(days: 10)),
      datosEmisor: _datosCompletos,
    );
    // Título sin la palabra "Vencida" a propósito -- el chip del filtro
    // se llama "Vencidas" y un find.textContaining('Vencida') también
    // lo encontraría a él, dando un falso positivo.
    await appData.facturas.add(_borrador('f2', 'c2', 'Pago atrasado'));
    await appData.facturas.emitir(
      'f2',
      fechaVencimiento: DateTime.now().subtract(const Duration(days: 3)),
      datosEmisor: _datosCompletos,
    );

    await tester.pumpWidget(
      MaterialApp(home: InvoicesListScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Al día'), findsOneWidget);
    expect(find.textContaining('Pago atrasado'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Vencidas'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pago atrasado'), findsOneWidget);
    expect(find.textContaining('Al día'), findsNothing);
  });

  testWidgets('el filtro "Borrador" no mezcla facturas ya emitidas', (
    tester,
  ) async {
    final appData = await _appDataConClientes();
    await appData.facturas.add(_borrador('f1', 'c1', 'Sigue en borrador'));
    await appData.facturas.add(_borrador('f2', 'c1', 'Ya emitida'));
    await appData.facturas.emitir('f2', datosEmisor: _datosCompletos);

    await tester.pumpWidget(
      MaterialApp(home: InvoicesListScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Borrador'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sigue en borrador'), findsOneWidget);
    expect(find.textContaining('Ya emitida'), findsNothing);
  });

  testWidgets('una factura demo nunca pierde su etiqueta DEMO en el listado', (
    tester,
  ) async {
    final appData = await _appDataConClientes();
    await appData.facturas.seedIfEmpty([
      Factura(
        id: 'demo1',
        clienteId: 'c1',
        titulo: 'Factura demo',
        esDemo: true,
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 10,
          ),
        ],
        creadaEl: DateTime(2026),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: InvoicesListScreen(appData: appData)),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEMO'), findsOneWidget);
  });
}
