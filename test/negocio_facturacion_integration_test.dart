// test/negocio_facturacion_integration_test.dart
//
// Integración entre "Mi negocio" y la emisión de facturas: bloqueo
// cuando faltan datos (con explicación y acceso directo a "Mi
// negocio"), conservación del borrador al volver, y que una factura ya
// emitida nunca cambia retroactivamente aunque se editen los datos del
// negocio después (encargo iteración 6, sección 10, puntos 8, 9, 10, 11
// y 12).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/features/invoices/invoice_detail_screen.dart';
import 'package:oficio_ai/features/settings/business_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppData> _appDataConFacturaBorrador() async {
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
  await appData.facturas.add(
    Factura(
      id: 'f1',
      clienteId: 'c1',
      titulo: 'Factura de prueba',
      conceptos: const [
        ConceptoPresupuesto(
          id: 'c1',
          descripcion: 'Servicio',
          cantidad: 1,
          precioUnitario: 100,
        ),
      ],
      creadaEl: DateTime(2026, 1, 1),
    ),
  );
  return appData;
}

Future<void> _scrollHasta(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'sin datos de negocio, intentar emitir explica qué falta, ofrece '
    'ir a "Mi negocio", NO emite y conserva el borrador tal cual',
    (tester) async {
      final appData = await _appDataConFacturaBorrador();
      expect(appData.negocio.datos, isNull);

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Emitir factura'));
      await tester.tap(find.text('Emitir factura'));
      await tester.pumpAndSettle();

      expect(find.text('Faltan datos de tu negocio'), findsOneWidget);
      expect(find.textContaining('Nombre o razón social'), findsOneWidget);
      expect(find.textContaining('NIF/CIF'), findsOneWidget);

      await tester.tap(find.text('Ir a Mi negocio'));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessSettingsScreen), findsOneWidget);

      // La factura sigue siendo un borrador intacto, con su concepto.
      final factura = appData.facturas.byId('f1')!;
      expect(factura.estado, EstadoFactura.borrador);
      expect(factura.numero, isNull);
      expect(factura.conceptos.single.descripcion, 'Servicio');
    },
  );

  testWidgets(
    'completar los datos del negocio y volver permite emitir',
    (tester) async {
      final appData = await _appDataConFacturaBorrador();

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Emitir factura'));
      await tester.tap(find.text('Emitir factura'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir a Mi negocio'));
      await tester.pumpAndSettle();

      // Rellena lo imprescindible directamente en el repositorio (el
      // formulario en sí, con sus validadores, ya lo cubre
      // business_settings_screen_test.dart) y vuelve.
      await appData.negocio.guardar(
        const DatosNegocio(
          nombreFiscal: 'Juan Pérez García',
          nif: '12345678Z',
          direccion: 'Calle Mayor 1',
          codigoPostal: '28001',
          localidad: 'Madrid',
          provincia: 'Madrid',
        ),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Emitir factura'));
      await tester.tap(find.text('Emitir factura'));
      await tester.pumpAndSettle();
      // Ahora si pasa el filtro, sigue el flujo normal: selector de
      // fecha de vencimiento (se cancela) y confirmación.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();

      final factura = appData.facturas.byId('f1')!;
      expect(factura.estado, EstadoFactura.emitida);
      expect(factura.numero, isNotNull);
      expect(factura.datosEmisor?.nombreFiscal, 'Juan Pérez García');
    },
  );

  test(
    'una factura ya emitida conserva su propio snapshot del emisor y su '
    'número aunque "Mi negocio" cambie después -- nunca cambia '
    'retroactivamente',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final appData = AppData(store);
      await Future.wait([
        appData.clientes.load(),
        appData.facturas.load(),
        appData.negocio.load(),
      ]);
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
      );
      await appData.negocio.guardar(
        const DatosNegocio(
          nombreFiscal: 'Nombre original',
          nif: '12345678Z',
          direccion: 'Calle Mayor 1',
          codigoPostal: '28001',
          localidad: 'Madrid',
          provincia: 'Madrid',
        ),
      );
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 100,
            ),
          ],
          creadaEl: DateTime(2026, 1, 1),
        ),
      );
      final emitida = await appData.facturas.emitir(
        'f1',
        datosEmisor: appData.negocio.datos!,
      );
      final numeroOriginal = emitida.numero;

      // Cambia el nombre, el NIF y el domicilio del negocio DESPUÉS de
      // emitir.
      await appData.negocio.guardar(
        const DatosNegocio(
          nombreFiscal: 'Nombre nuevo, S.L.',
          nif: 'B87654321',
          direccion: 'Otra calle 99',
          codigoPostal: '08001',
          localidad: 'Barcelona',
          provincia: 'Barcelona',
        ),
      );

      final facturaReleida = appData.facturas.byId('f1')!;
      expect(facturaReleida.numero, numeroOriginal);
      expect(facturaReleida.datosEmisor!.nombreFiscal, 'Nombre original');
      expect(facturaReleida.datosEmisor!.nif, '12345678Z');
      expect(facturaReleida.datosEmisor!.localidad, 'Madrid');
    },
  );

  test(
    'facturas emitidas antes de que existiera esta funcionalidad '
    '(datosEmisor ausente en el JSON) se leen sin lanzar',
    () async {
      final json = {
        'id': 'antigua',
        'clienteId': 'c1',
        'titulo': 'Factura antigua',
        'conceptos': <Map<String, dynamic>>[],
        'estado': 'emitida',
        'anio': 2026,
        'numeroSecuencial': 1,
        'creadaEl': DateTime(2026).toIso8601String(),
        'fechaEmision': DateTime(2026).toIso8601String(),
        // Sin 'datosEmisor' -- así se guardaba antes de esta iteración.
      };
      final f = Factura.fromJson(json);
      expect(f.datosEmisor, isNull);
      expect(f.numero, '2026-0001');
    },
  );
}
