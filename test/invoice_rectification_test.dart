// test/invoice_rectification_test.dart
//
// Flujo de "Rectificar factura" dirigido por la interfaz (iteración 8,
// encargo sección 9 y 10): el botón aparece en una factura emitida,
// crea y emite una rectificativa con su propia numeración, protege
// contra un doble toque en "Emitir rectificativa" (mismo patrón que
// "Registrar cobro" en invoice_flow_test.dart) y valida el motivo antes
// de emitir.
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
import 'package:oficio_ai/features/invoices/invoice_rectification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Future<AppData> _appDataConFacturaEmitida() async {
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
  await appData.negocio.guardar(_datosCompletos);
  await appData.clientes.add(
    Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
  );
  await appData.facturas.add(
    Factura(
      id: 'f1',
      clienteId: 'c1',
      titulo: 'Factura original',
      conceptos: const [
        ConceptoPresupuesto(
          id: 'c1',
          descripcion: 'Reparación',
          cantidad: 1,
          precioUnitario: 100,
        ),
      ],
      creadaEl: DateTime(2026, 1, 1),
    ),
  );
  await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
  return appData;
}

Future<void> _scrollHasta(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'el botón "Rectificar factura" de una factura emitida abre la '
    'pantalla de rectificación con la factura original identificada',
    (tester) async {
      final appData = await _appDataConFacturaEmitida();
      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Rectificar factura'));
      await tester.tap(find.text('Rectificar factura'));
      await tester.pumpAndSettle();

      expect(find.byType(InvoiceRectificationScreen), findsOneWidget);
      final original = appData.facturas.byId('f1')!;
      expect(find.textContaining(original.numero!), findsOneWidget);
    },
  );

  testWidgets(
    'emitir sin motivo no crea ninguna rectificativa y avisa',
    (tester) async {
      final appData = await _appDataConFacturaEmitida();
      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceRectificationScreen(
            appData: appData,
            facturaOriginal: appData.facturas.byId('f1')!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Emitir rectificativa'));
      await tester.pumpAndSettle();

      expect(find.textContaining('motivo'), findsWidgets);
      expect(appData.facturas.facturas, hasLength(1)); // solo la original
    },
  );

  testWidgets(
    'completar motivo, dejar la diferencia por defecto y emitir crea '
    'una rectificativa emitida con numeración propia (serie "R") y deja '
    'consultable la relación con la original',
    (tester) async {
      final appData = await _appDataConFacturaEmitida();
      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceRectificationScreen(
            appData: appData,
            facturaOriginal: appData.facturas.byId('f1')!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo de la rectificación *'),
        'Error en la cantidad facturada',
      );
      // Fila de concepto por defecto ("Corrección", cantidad 1, precio
      // 0) -- se rellena con una diferencia negativa real.
      await tester.enterText(find.widgetWithText(TextField, 'Precio (€)'), '-20');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Emitir rectificativa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Emitir'));
      await tester.pumpAndSettle();

      expect(appData.facturas.facturas, hasLength(2));
      final rectificativa = appData.facturas.facturas.firstWhere(
        (f) => f.tipoDocumento == TipoDocumentoFactura.rectificativa,
      );
      expect(rectificativa.estado, EstadoFactura.emitida);
      expect(rectificativa.serie, serieRectificativas);
      expect(rectificativa.facturaOriginalId, 'f1');
      expect(rectificativa.numero, startsWith('$serieRectificativas-'));
      expect(appData.facturas.rectificativasDe('f1'), hasLength(1));

      // Navegó a la ficha de la rectificativa recién emitida.
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
      await _scrollHasta(tester, find.text('Rectifica a'));
      expect(find.text('Rectifica a'), findsOneWidget);
    },
  );

  testWidgets(
    'un doble toque en "Emitir rectificativa" no crea dos rectificativas',
    (tester) async {
      final appData = await _appDataConFacturaEmitida();
      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceRectificationScreen(
            appData: appData,
            facturaOriginal: appData.facturas.byId('f1')!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo de la rectificación *'),
        'Error en el importe',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Precio (€)'), '-15');
      await tester.pumpAndSettle();

      // Dos toques seguidos en el botón PRINCIPAL, sin esperar entre
      // medias -- debe quedar deshabilitado desde el primer toque
      // (antes incluso de que aparezca el diálogo de confirmación), no
      // solo después de confirmarlo.
      final botonPrincipal = find.widgetWithText(FilledButton, 'Emitir rectificativa');
      await tester.tap(botonPrincipal, warnIfMissed: false);
      await tester.tap(botonPrincipal, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget); // solo un diálogo abierto
      await tester.tap(find.widgetWithText(FilledButton, 'Emitir'));
      await tester.pumpAndSettle();

      final rectificativas = appData.facturas.facturas
          .where((f) => f.tipoDocumento == TipoDocumentoFactura.rectificativa)
          .toList();
      expect(rectificativas, hasLength(1));
    },
  );
}
