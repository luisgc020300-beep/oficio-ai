// test/invoice_pdf_preview_test.dart
//
// Integración de "Ver PDF" desde la ficha de factura: navegación, aviso
// explícito cuando faltan datos históricos del emisor (con "Cancelar" y
// "Generar igualmente"), y que abrir/generar la vista previa nunca
// cambia nada de la factura -- ni estado, ni número, ni conceptos, ni
// pagos (encargo iteración 7, sección 10, puntos 12-15).
//
// Nota sobre alcance: PdfPreview (paquete `printing`) rasteriza páginas
// a través de un canal de plataforma nativo para dibujarlas en
// pantalla -- eso no está disponible en el entorno de `flutter test`
// (no hay plugin nativo registrado), así que estos tests no abren esa
// previsualización rasterizada ni tocan sus botones de imprimir/
// compartir (que son otro canal de plataforma, el selector nativo del
// sistema). Lo que SÍ se verifica aquí, y es lo que de verdad protege
// el encargo, es que la pantalla de vista previa y el servicio de PDF
// no tienen ningún camino de código que escriba en ningún repositorio
// -- ver también factura_pdf_service_test.dart, que ya prueba que
// generar() no modifica la factura.
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
import 'package:oficio_ai/features/invoices/invoice_pdf_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'el botón "Ver PDF" en una factura emitida con datos completos '
    'abre la vista previa directamente, sin avisos',
    (tester) async {
      final appData = await _appDataConCliente();
      await appData.negocio.guardar(_datosCompletos);
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
      await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      final factura = appData.facturas.byId('f1')!;
      final numeroAntes = factura.numero;
      final estadoAntes = factura.estado;
      final pagosAntes = factura.pagos;

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver PDF'));
      // pump() con duración, no pumpAndSettle(): PdfPreview se queda
      // indefinidamente en su indicador de carga porque intenta
      // rasterizar la página a través de un plugin nativo que no existe
      // en este entorno de test (pumpAndSettle no terminaría nunca).
      // skipOffstage: false porque, a mitad de la transición de la
      // ruta, la nueva pantalla todavía cuenta como offstage para los
      // finders -- aunque ya está montada y es justo lo que aquí se
      // comprueba: que navegó, con qué título, y que la factura sigue
      // intacta.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(InvoicePdfPreviewScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text(numeroAntes!), findsWidgets);
      // Ningún diálogo de aviso -- hay fotografía histórica completa.
      expect(find.text('Faltan datos históricos del emisor'), findsNothing);

      final facturaDespues = appData.facturas.byId('f1')!;
      expect(facturaDespues.numero, numeroAntes);
      expect(facturaDespues.estado, estadoAntes);
      expect(facturaDespues.pagos, pagosAntes);
    },
  );

  testWidgets(
    'una factura emitida SIN datos históricos del emisor muestra el '
    'aviso antes de generar, y "Cancelar" no navega a la vista previa',
    (tester) async {
      final appData = await _appDataConCliente();
      // Se siembra directamente YA emitida pero sin datosEmisor --
      // simula una factura de antes de la iteración 6 (emitir() de hoy
      // ya no permite esta combinación).
      await appData.facturas.seedIfEmpty([
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura antigua',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 100,
            ),
          ],
          estado: EstadoFactura.emitida,
          anio: 2025,
          numeroSecuencial: 1,
          creadaEl: DateTime(2025, 1, 1),
          fechaEmision: DateTime(2025, 1, 2),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Faltan datos históricos del emisor'), findsOneWidget);
      expect(find.byType(InvoicePdfPreviewScreen), findsNothing);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(InvoicePdfPreviewScreen), findsNothing);
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
    },
  );

  testWidgets(
    '"Generar igualmente" en ese mismo caso navega a la vista previa '
    'sin alterar la factura', (tester) async {
      final appData = await _appDataConCliente();
      await appData.facturas.seedIfEmpty([
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura antigua',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 100,
            ),
          ],
          estado: EstadoFactura.emitida,
          anio: 2025,
          numeroSecuencial: 1,
          creadaEl: DateTime(2025, 1, 1),
          fechaEmision: DateTime(2025, 1, 2),
        ),
      ]);
      final antes = appData.facturas.byId('f1')!;

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar igualmente'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(InvoicePdfPreviewScreen, skipOffstage: false), findsOneWidget);

      final despues = appData.facturas.byId('f1')!;
      expect(despues.numero, antes.numero);
      expect(despues.estado, antes.estado);
      expect(despues.datosEmisor, isNull); // sigue sin rellenarse en silencio
    },
  );

  testWidgets(
    'ver el PDF de un borrador no lo emite ni le asigna número',
    (tester) async {
      final appData = await _appDataConCliente();
      await appData.negocio.guardar(_datosCompletos);
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Borrador de factura',
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

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver PDF'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(InvoicePdfPreviewScreen, skipOffstage: false), findsOneWidget);

      final factura = appData.facturas.byId('f1')!;
      expect(factura.estado, EstadoFactura.borrador);
      expect(factura.numero, isNull);
      expect(factura.datosEmisor, isNull);
    },
  );

  testWidgets(
    'ver el PDF de una factura anulada no cambia su estado ni su motivo',
    (tester) async {
      final appData = await _appDataConCliente();
      await appData.negocio.guardar(_datosCompletos);
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura a anular',
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
      await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await appData.facturas.anular('f1', 'Error en el importe');
      final antes = appData.facturas.byId('f1')!;

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver PDF'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(InvoicePdfPreviewScreen, skipOffstage: false), findsOneWidget);

      final despues = appData.facturas.byId('f1')!;
      expect(despues.estado, EstadoFactura.anulada);
      expect(despues.motivoAnulacion, antes.motivoAnulacion);
      expect(despues.numero, antes.numero);
    },
  );
}
