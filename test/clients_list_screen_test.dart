// test/clients_list_screen_test.dart
//
// Búsqueda (nombre, teléfono, correo) y filtros sencillos de la lista de
// clientes (iteración 11). Ningún filtro etiqueta a nadie de moroso
// solo por tener saldo pendiente -- "con saldo pendiente" es un hecho,
// no un juicio sobre si está vencido.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/nota_seguimiento.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/clients/clients_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

// La fila de chips de filtro es un ListView horizontal -- un chip a la
// derecha puede quedar fuera del viewport del test (800dp), sin
// siquiera llegar a construirse. scrollUntilVisible() desplaza en
// pasos pequeños y vuelve a comprobar tras cada uno (a diferencia de
// ensureVisible(), que exige que el widget ya exista). Se apunta al
// Scrollable de la propia fila de chips por su Key -- el TextField de
// búsqueda es también un Scrollable (por el cursor), así que adivinar
// "el primero" es frágil.
Future<void> _scrollHastaChip(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
  finder,
  80,
  scrollable: find.descendant(
    of: find.byKey(const Key('filtroClienteChips')),
    matching: find.byType(Scrollable),
  ),
);

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
    appData.negocio.load(),
    appData.notasSeguimiento.load(),
  ]);
  return appData;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets('la búsqueda encuentra por nombre, por teléfono y por correo', (tester) async {
    final appData = await _appDataVacia();
    await appData.clientes.add(
      Cliente(id: 'c1', nombre: 'Marta Iglesias', telefono: '611222333', creadoEl: DateTime(2026)),
    );
    await appData.clientes.add(
      Cliente(id: 'c2', nombre: 'Rubén Castaño', email: 'ruben@correo.com', creadoEl: DateTime(2026)),
    );
    await appData.clientes.add(
      Cliente(id: 'c3', nombre: 'Comunidad Jardines', creadoEl: DateTime(2026)),
    );

    await tester.pumpWidget(MaterialApp(home: ClientsListScreen(appData: appData)));
    await tester.pumpAndSettle();
    expect(find.text('Marta Iglesias'), findsOneWidget);
    expect(find.text('Rubén Castaño'), findsOneWidget);
    expect(find.text('Comunidad Jardines'), findsOneWidget);

    final buscador = find.byType(TextField);

    await tester.enterText(buscador, 'rubén');
    await tester.pumpAndSettle();
    expect(find.text('Marta Iglesias'), findsNothing);
    expect(find.text('Rubén Castaño'), findsOneWidget);

    await tester.enterText(buscador, '611222');
    await tester.pumpAndSettle();
    expect(find.text('Marta Iglesias'), findsOneWidget);
    expect(find.text('Rubén Castaño'), findsNothing);

    await tester.enterText(buscador, 'ruben@correo');
    await tester.pumpAndSettle();
    expect(find.text('Rubén Castaño'), findsOneWidget);
    expect(find.text('Marta Iglesias'), findsNothing);

    await tester.enterText(buscador, 'ningún cliente coincide con esto');
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('filtro "Trabajos activos" solo muestra clientes con un trabajo pendiente o en curso', (
    tester,
  ) async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Con trabajo activo', creadoEl: DateTime(2026)));
    await appData.clientes.add(
      Cliente(id: 'c2', nombre: 'Con trabajo finalizado', creadoEl: DateTime(2026)),
    );
    await appData.clientes.add(Cliente(id: 'c3', nombre: 'Sin trabajos', creadoEl: DateTime(2026)));
    await appData.trabajos.add(
      Trabajo(
        id: 't1',
        clienteId: 'c1',
        titulo: 'En curso',
        estado: EstadoTrabajo.enCurso,
        creadoEl: DateTime(2026),
      ),
    );
    await appData.trabajos.add(
      Trabajo(
        id: 't2',
        clienteId: 'c2',
        titulo: 'Ya acabado',
        estado: EstadoTrabajo.finalizado,
        creadoEl: DateTime(2026),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ClientsListScreen(appData: appData)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajos activos'));
    await tester.pumpAndSettle();

    expect(find.text('Con trabajo activo'), findsOneWidget);
    expect(find.text('Con trabajo finalizado'), findsNothing);
    expect(find.text('Sin trabajos'), findsNothing);
  });

  testWidgets(
    'filtro "Presupuestos pendientes" solo muestra clientes con un presupuesto enviado',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Con envío pendiente', creadoEl: DateTime(2026)));
      await appData.clientes.add(Cliente(id: 'c2', nombre: 'Con aceptado', creadoEl: DateTime(2026)));
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p1',
          clienteId: 'c1',
          titulo: 'Presupuesto 1',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoPresupuesto.enviado,
          creadoEl: DateTime(2026),
        ),
      );
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p2',
          clienteId: 'c2',
          titulo: 'Presupuesto 2',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoPresupuesto.aceptado,
          creadoEl: DateTime(2026),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: ClientsListScreen(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Presupuestos pendientes'));
      await tester.pumpAndSettle();

      expect(find.text('Con envío pendiente'), findsOneWidget);
      expect(find.text('Con aceptado'), findsNothing);
    },
  );

  testWidgets(
    'filtro "Con saldo pendiente" solo muestra clientes con una factura emitida sin cobrar del '
    'todo -- no clasifica de moroso solo por tener saldo',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Debe parte', creadoEl: DateTime(2026)));
      await appData.clientes.add(Cliente(id: 'c2', nombre: 'Ya pagó todo', creadoEl: DateTime(2026)));
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura 1',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 100),
          ],
          creadaEl: DateTime(2026),
        ),
      );
      await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await appData.facturas.add(
        Factura(
          id: 'f2',
          clienteId: 'c2',
          titulo: 'Factura 2',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 100),
          ],
          creadaEl: DateTime(2026),
        ),
      );
      await appData.facturas.emitir('f2', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f2', fecha: DateTime(2026), importe: 121);

      await tester.pumpWidget(MaterialApp(home: ClientsListScreen(appData: appData)));
      await tester.pumpAndSettle();

      final chip = find.widgetWithText(ChoiceChip, 'Con saldo pendiente');
      await _scrollHastaChip(tester, chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Debe parte'), findsOneWidget);
      expect(find.text('Ya pagó todo'), findsNothing);
    },
  );

  testWidgets(
    'filtro "Seguimiento programado" solo muestra clientes con un seguimiento pendiente',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Con seguimiento', creadoEl: DateTime(2026)));
      await appData.clientes.add(
        Cliente(id: 'c2', nombre: 'Seguimiento ya cancelado', creadoEl: DateTime(2026)),
      );
      await appData.clientes.add(Cliente(id: 'c3', nombre: 'Sin notas', creadoEl: DateTime(2026)));
      await appData.notasSeguimiento.add(
        NotaSeguimiento(
          id: 'n1',
          clienteId: 'c1',
          texto: 'Llamar la semana que viene',
          creadoEl: DateTime(2026),
          fechaSeguimiento: DateTime(2026, 12, 1),
        ),
      );
      await appData.notasSeguimiento.add(
        NotaSeguimiento(
          id: 'n2',
          clienteId: 'c2',
          texto: 'Ya no hace falta',
          creadoEl: DateTime(2026),
          fechaSeguimiento: DateTime(2026, 12, 1),
        ),
      );
      await appData.notasSeguimiento.marcarSeguimientoCancelado('n2');

      await tester.pumpWidget(MaterialApp(home: ClientsListScreen(appData: appData)));
      await tester.pumpAndSettle();

      final chip = find.widgetWithText(ChoiceChip, 'Seguimiento programado');
      await _scrollHastaChip(tester, chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Con seguimiento'), findsOneWidget);
      expect(find.text('Seguimiento ya cancelado'), findsNothing);
      expect(find.text('Sin notas'), findsNothing);
    },
  );
}
