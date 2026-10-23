// test/dashboard_economico_test.dart
//
// Resumen económico del dashboard: la facturación se agrupa por fecha
// de EMISIÓN y los cobros por fecha EFECTIVA del pago -- deliberadamente
// pueden caer en meses distintos y no deben mezclarse. También cubre
// presupuestos aceptados sin facturar y el contador de facturas
// vencidas (encargo iteración 5, sección 12, puntos 5, 15 y 16).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/pago_factura.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/features/dashboard/dashboard_screen.dart';
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
  ]);
  return appData;
}

/// "Resumen económico" vive más abajo del scroll del dashboard -- hay
/// que desplazarse hasta ahí antes de poder encontrar sus textos (el
/// body es un ListView, que solo materializa lo cercano al viewport).
Future<void> _scrollAResumenEconomico(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Últimos 6 meses'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'el total facturado del mes usa la fecha de emisión; el cobrado '
    'usa la fecha efectiva del pago, aunque caigan en meses distintos',
    (tester) async {
      final appData = await _appDataVacia();
      final hoy = DateTime.now();
      final mesAnterior = DateTime(hoy.year, hoy.month - 1, 15);

      // Sembrada ya emitida el mes pasado (fuera del mes actual) pero
      // con un pago registrado HOY. emitir() siempre usa la fecha real
      // como fecha de emisión (no es editable), así que para fijar un
      // mes de emisión distinto al actual en el test se construye la
      // factura directamente, vía seedIfEmpty -- el mismo mecanismo que
      // usa demo_seed.dart, que tampoco pasa por el flujo de emitir().
      await appData.facturas.seedIfEmpty([
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura mes anterior',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 100,
            ),
          ],
          estado: EstadoFactura.emitida,
          anio: mesAnterior.year,
          numeroSecuencial: 1,
          creadaEl: mesAnterior,
          fechaEmision: mesAnterior,
          pagos: [
            PagoFactura(
              id: 'pago1',
              fecha: hoy,
              importe: 121,
              registradoEl: hoy,
            ),
          ],
        ),
      ]);

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
      await _scrollAResumenEconomico(tester);

      // Facturada el mes pasado -> no suma al "Facturado este mes" (0 €
      // en el actual), pero cobrada hoy -> sí suma a "Cobrado este mes"
      // (121 €), aunque sea la misma factura. formatCurrency() separa
      // importe y símbolo con un espacio irrompible (U+00A0), no uno
      // normal -- de ahí el   explícito.
      expect(find.text('0,00 €'), findsWidgets);
      expect(find.text('121,00 €'), findsWidgets);
    },
  );

  testWidgets(
    'presupuestos aceptados sin facturar: cuenta solo si no hay ninguna '
    'factura EMITIDA desde ese presupuesto (un borrador no basta)',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p1',
          clienteId: 'c1',
          titulo: 'Presupuesto aceptado',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 50,
            ),
          ],
          estado: EstadoPresupuesto.aceptado,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );

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
      await _scrollAResumenEconomico(tester);
      expect(
        find.textContaining('1 presupuesto aceptado sin facturar'),
        findsOneWidget,
      );

      // Un borrador de factura desde ese presupuesto no lo quita del
      // aviso -- todavía no se ha facturado de verdad.
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          presupuestoId: 'p1',
          titulo: 'Borrador desde el presupuesto',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 50,
            ),
          ],
          creadaEl: DateTime(2026, 1, 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1 presupuesto aceptado sin facturar'),
        findsOneWidget,
      );

      // Al emitirla, el aviso desaparece.
      await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await tester.pumpAndSettle();
      expect(find.textContaining('presupuesto aceptado sin facturar'), findsNothing);
    },
  );

  testWidgets('una factura vencida sin cobrar cuenta en "Facturas vencidas"', (
    tester,
  ) async {
    final appData = await _appDataVacia();
    await appData.facturas.add(
      Factura(
        id: 'f1',
        clienteId: 'c1',
        titulo: 'Factura vencida',
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 50,
          ),
        ],
        creadaEl: DateTime(2026, 1, 1),
      ),
    );
    await appData.facturas.emitir(
      'f1',
      fechaVencimiento: DateTime.now().subtract(const Duration(days: 5)),
      datosEmisor: _datosCompletos,
    );

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
    await _scrollAResumenEconomico(tester);

    expect(find.text('1'), findsWidgets);
    expect(find.text('Factura vencida'), findsOneWidget);
  });
}
