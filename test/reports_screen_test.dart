// test/reports_screen_test.dart
//
// Informes y estadísticas del negocio (iteración 12): rango de cada
// periodo, facturación (con rectificativas y facturas anuladas, mismo
// criterio que el resto de la app -- valores calculados aquí a mano),
// gastos por categoría, trabajos por estado, tasa de conversión de
// presupuestos (sin inventar una tendencia cuando no hay nada decidido
// todavía) y clientes que más facturan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/core/utils/formatters.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/gasto.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/reports/reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
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

Future<void> _scrollHasta(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('rangoPeriodo()', () {
    test('esteMes: del día 1 del mes al día 1 del siguiente', () {
      final ahora = DateTime(2026, 3, 15);
      expect(rangoPeriodo(Periodo.esteMes, ahora), (DateTime(2026, 3), DateTime(2026, 4)));
    });

    test('esteTrimestre: agrupa en bloques de 3 meses del año natural', () {
      expect(
        rangoPeriodo(Periodo.esteTrimestre, DateTime(2026, 2, 10)),
        (DateTime(2026, 1), DateTime(2026, 4)),
      );
      expect(
        rangoPeriodo(Periodo.esteTrimestre, DateTime(2026, 8, 1)),
        (DateTime(2026, 7), DateTime(2026, 10)),
      );
      expect(
        rangoPeriodo(Periodo.esteTrimestre, DateTime(2026, 12, 31)),
        (DateTime(2026, 10), DateTime(2027, 1)),
      );
    });

    test('esteAnio: de enero a enero del año siguiente', () {
      expect(rangoPeriodo(Periodo.esteAnio, DateTime(2026, 6, 1)), (DateTime(2026), DateTime(2027)));
    });

    test('todo: sin límites -- null, nunca una fecha de inicio inventada', () {
      expect(rangoPeriodo(Periodo.todo, DateTime(2026, 6, 1)), isNull);
    });
  });

  testWidgets(
    'facturación del mes: factura parcialmente cobrada, otra cobrada, una anulada y una '
    'rectificativa -- nunca cuenta dos veces ni incluye lo anulado',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      Factura ordinaria(String id, double precio) => Factura(
        id: id,
        clienteId: 'c1',
        titulo: 'Factura $id',
        conceptos: [
          ConceptoPresupuesto(id: 'c1', descripcion: 'Servicio', cantidad: 1, precioUnitario: precio),
        ],
        creadaEl: DateTime.now(),
      );

      // f1: 200 + 21% = 242, cobrada parcialmente (100).
      await appData.facturas.add(ordinaria('f1', 200));
      final f1 = await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f1', fecha: DateTime.now(), importe: 100);

      // f2: 100 + 21% = 121, cobrada en su totalidad.
      await appData.facturas.add(ordinaria('f2', 100));
      await appData.facturas.emitir('f2', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f2', fecha: DateTime.now(), importe: 121);

      // f3: 50 + 21% = 60,50, pero ANULADA -- no debe contar en nada.
      await appData.facturas.add(ordinaria('f3', 50));
      await appData.facturas.emitir('f3', datosEmisor: _datosCompletos);
      await appData.facturas.anular('f3', 'Presupuesto duplicado por error');

      // r1: rectificativa "por diferencias" de f1, -20 de base -> -24,20.
      await appData.facturas.add(
        Factura(
          id: 'r1',
          clienteId: 'c1',
          titulo: 'Rectificativa de f1',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'Corrección', cantidad: 1, precioUnitario: -20),
          ],
          creadaEl: DateTime.now(),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: f1.id,
          motivoRectificacion: 'Cantidad facturada por error',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      await appData.facturas.emitir('r1', datosEmisor: _datosCompletos);

      await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
      await tester.pumpAndSettle();

      // Cálculo independiente: Facturado = 242+121-24,20 = 338,80
      // Cobrado = 100+121 = 221,00. Pendiente = 142+0+0 = 142,00.
      expect(find.text(formatCurrency(338.8)), findsWidgets);
      expect(find.text(formatCurrency(221.0)), findsWidgets);
      expect(find.text(formatCurrency(142.0)), findsWidgets);
      expect(find.text(formatCurrency(60.5)), findsNothing);
    },
  );

  testWidgets('gastos por categoría: suma por categoría y el total general', (tester) async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
    await appData.gastos.add(
      Gasto(
        id: 'g1',
        descripcion: 'Tubos',
        importe: 30,
        fecha: DateTime.now(),
        categoria: CategoriaGasto.materiales,
        creadoEl: DateTime.now(),
      ),
    );
    await appData.gastos.add(
      Gasto(
        id: 'g2',
        descripcion: 'Más tubos',
        importe: 20,
        fecha: DateTime.now(),
        categoria: CategoriaGasto.materiales,
        creadoEl: DateTime.now(),
      ),
    );
    await appData.gastos.add(
      Gasto(
        id: 'g3',
        descripcion: 'Gasolina',
        importe: 15,
        fecha: DateTime.now(),
        categoria: CategoriaGasto.desplazamiento,
        creadoEl: DateTime.now(),
      ),
    );
    // Gasto anulado -- nunca debe computar (ver Gasto.estado).
    await appData.gastos.add(
      Gasto(
        id: 'g4',
        descripcion: 'Por error',
        importe: 999,
        fecha: DateTime.now(),
        categoria: CategoriaGasto.herramientas,
        creadoEl: DateTime.now(),
      ),
    );
    await appData.gastos.anular('g4', 'Registrado por error');

    await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
    await tester.pumpAndSettle();

    expect(find.text('Materiales'), findsOneWidget);
    expect(find.text(formatCurrency(50.0)), findsOneWidget); // 30+20
    expect(find.text('Desplazamiento'), findsOneWidget);
    expect(find.text(formatCurrency(15.0)), findsOneWidget);
    await _scrollHasta(tester, find.text('Total gastado'));
    expect(find.text(formatCurrency(65.0)), findsOneWidget); // 30+20+15, sin el anulado
    expect(find.text('Herramientas'), findsNothing);
  });

  testWidgets('trabajos dados de alta en el periodo, agrupados por estado', (tester) async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
    await appData.trabajos.add(
      Trabajo(
        id: 't1',
        clienteId: 'c1',
        titulo: 'Trabajo 1',
        estado: EstadoTrabajo.enCurso,
        creadoEl: DateTime.now(),
      ),
    );
    await appData.trabajos.add(
      Trabajo(
        id: 't2',
        clienteId: 'c1',
        titulo: 'Trabajo 2',
        estado: EstadoTrabajo.enCurso,
        creadoEl: DateTime.now(),
      ),
    );
    await appData.trabajos.add(
      Trabajo(
        id: 't3',
        clienteId: 'c1',
        titulo: 'Trabajo 3',
        estado: EstadoTrabajo.finalizado,
        creadoEl: DateTime.now(),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
    await tester.pumpAndSettle();
    await _scrollHasta(tester, find.text('Trabajos dados de alta en el periodo'));

    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing); // ninguno en ese estado, no se muestra en cero
  });

  group('presupuestos: tasa de conversión', () {
    testWidgets('con aceptados y rechazados, calcula el porcentaje', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      for (var i = 0; i < 3; i++) {
        await appData.presupuestos.add(
          Presupuesto(
            id: 'acept$i',
            clienteId: 'c1',
            titulo: 'Presupuesto $i',
            conceptos: const [
              ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
            ],
            estado: EstadoPresupuesto.aceptado,
            creadoEl: DateTime.now(),
          ),
        );
      }
      await appData.presupuestos.add(
        Presupuesto(
          id: 'rechazado',
          clienteId: 'c1',
          titulo: 'Presupuesto rechazado',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoPresupuesto.rechazado,
          creadoEl: DateTime.now(),
        ),
      );
      // Enviado, todavía sin decidir -- no debe entrar en la tasa.
      await appData.presupuestos.add(
        Presupuesto(
          id: 'enviado',
          clienteId: 'c1',
          titulo: 'Presupuesto enviado',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoPresupuesto.enviado,
          creadoEl: DateTime.now(),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
      await tester.pumpAndSettle();
      await _scrollHasta(tester, find.text('Tasa de conversión'));

      // 3 de 4 decididos (3 aceptados + 1 rechazado) = 75%.
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('sin ningún presupuesto decidido todavía, no inventa un 0%', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.presupuestos.add(
        Presupuesto(
          id: 'enviado',
          clienteId: 'c1',
          titulo: 'Presupuesto enviado',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoPresupuesto.enviado,
          creadoEl: DateTime.now(),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
      await tester.pumpAndSettle();
      await _scrollHasta(tester, find.text('Tasa de conversión'));

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });
  });

  testWidgets(
    'clientes que más facturan: ordenados de mayor a menor, solo con facturación real',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Factura poco', creadoEl: DateTime(2026)));
      await appData.clientes.add(Cliente(id: 'c2', nombre: 'Factura mucho', creadoEl: DateTime(2026)));
      await appData.clientes.add(Cliente(id: 'c3', nombre: 'Sin facturas', creadoEl: DateTime(2026)));

      Future<void> facturar(String clienteId, String facturaId, double precio) async {
        await appData.facturas.add(
          Factura(
            id: facturaId,
            clienteId: clienteId,
            titulo: 'Factura $facturaId',
            conceptos: [
              ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: precio),
            ],
            creadaEl: DateTime.now(),
          ),
        );
        await appData.facturas.emitir(facturaId, datosEmisor: _datosCompletos);
      }

      await facturar('c1', 'f1', 50);
      await facturar('c2', 'f2', 500);

      await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
      await tester.pumpAndSettle();
      await _scrollHasta(tester, find.text('Clientes que más facturan'));

      final nombres = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == 'Factura mucho' || t == 'Factura poco')
          .toList();
      expect(nombres, ['Factura mucho', 'Factura poco']); // orden: mayor primero
      expect(find.text('Sin facturas'), findsNothing);

      await tester.tap(find.text('Factura mucho'));
      await tester.pumpAndSettle();
      expect(find.text('Factura mucho'), findsWidgets); // ahora también en la ficha del cliente
    },
  );

  testWidgets(
    'sin facturas, gastos, trabajos ni presupuestos en el periodo, muestra el estado vacío',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
      await tester.pumpAndSettle();

      expect(find.text('Sin datos en este periodo'), findsOneWidget);
      expect(find.text('Facturación'), findsNothing);
    },
  );

  testWidgets('cambiar a "Todo" incluye datos fuera del mes actual', (tester) async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
    // creadoEl es libre en Trabajo (no hay un flujo tipo "emitir" que lo
    // fije a "ahora"), así que sirve para simular un trabajo antiguo.
    await appData.trabajos.add(
      Trabajo(
        id: 't1',
        clienteId: 'c1',
        titulo: 'Trabajo antiguo',
        estado: EstadoTrabajo.finalizado,
        creadoEl: DateTime(2020, 1, 15),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ReportsScreen(appData: appData)));
    await tester.pumpAndSettle();

    // "Este mes" (por defecto) no debe verlo.
    expect(find.text('Sin datos en este periodo'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todo'));
    await tester.pumpAndSettle();

    expect(find.text('Sin datos en este periodo'), findsNothing);
    expect(find.text('Trabajos dados de alta en el periodo'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
  });
}
