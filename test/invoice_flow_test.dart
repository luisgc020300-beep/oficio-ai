// test/invoice_flow_test.dart
//
// Flujo dirigido por la interfaz: crear una factura desde un trabajo
// terminado (reutilizando cliente y conceptos del presupuesto de
// origen), emitirla, registrar un cobro parcial y el cobro final, y
// validación del formulario de cobro -- incluida la protección contra
// un doble toque en "Registrar cobro" (encargo iteración 5, sección 12,
// puntos 3, 4, 9, 10 y 20).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/invoices/invoice_detail_screen.dart';
import 'package:oficio_ai/features/jobs/job_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Este archivo prueba el flujo de emitir/cobrar, no la integración con
// "Mi negocio" (eso vive en negocio_test.dart) -- se deja precargada y
// completa para que el diálogo de "faltan datos" nunca interrumpa estos
// tests (encargo iteración 6, sección 6).
const _datosNegocioCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Future<AppData> _appDataConTrabajoTerminado() async {
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
  await appData.negocio.guardar(_datosNegocioCompletos);
  await appData.clientes.add(
    Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
  );
  await appData.presupuestos.add(
    Presupuesto(
      id: 'p1',
      clienteId: 'c1',
      trabajoId: 't1',
      titulo: 'Presupuesto cambio de grifo',
      conceptos: const [
        ConceptoPresupuesto(
          id: 'c1',
          descripcion: 'Grifo nuevo',
          cantidad: 1,
          precioUnitario: 45,
        ),
      ],
      estado: EstadoPresupuesto.aceptado,
      creadoEl: DateTime(2026, 1, 1),
    ),
  );
  await appData.trabajos.add(
    Trabajo(
      id: 't1',
      clienteId: 'c1',
      titulo: 'Cambio de grifo',
      estado: EstadoTrabajo.finalizado,
      creadoEl: DateTime(2026, 1, 1),
      presupuestoId: 'p1',
    ),
  );
  return appData;
}

/// El detalle de factura es un ListView largo (conceptos, totales,
/// historial de cobros...) -- sus botones suelen quedar fuera del
/// viewport inicial y hay que desplazarse hasta ellos antes de poder
/// tocarlos (mismo motivo que en calendar_agenda_test.dart).
Future<void> _scrollHasta(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'crear factura desde un trabajo terminado reutiliza cliente y '
    'conceptos del presupuesto de origen, y conserva ambas relaciones',
    (tester) async {
      final appData = await _appDataConTrabajoTerminado();

      await tester.pumpWidget(
        MaterialApp(home: JobDetailScreen(appData: appData, trabajoId: 't1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Este trabajo todavía no tiene factura.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Crear factura'));
      await tester.pumpAndSettle();

      // El concepto del presupuesto llega precargado al formulario.
      expect(find.text('Grifo nuevo'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar borrador'));
      await tester.pumpAndSettle();

      // De vuelta en la ficha del trabajo, la factura recién creada
      // aparece en su sección, conservando cliente/trabajo/presupuesto.
      expect(find.text('Este trabajo todavía no tiene factura.'), findsNothing);
      final factura = appData.facturas.facturas.single;
      expect(factura.clienteId, 'c1');
      expect(factura.trabajoId, 't1');
      expect(factura.presupuestoId, 'p1');
      expect(factura.estado, EstadoFactura.borrador);
      expect(factura.conceptos.single.descripcion, 'Grifo nuevo');
    },
  );

  testWidgets(
    'emitir, cobrar parcialmente y después cobrar el resto deja el '
    'saldo en cero y la factura como pagada',
    (tester) async {
      final appData = await _appDataConTrabajoTerminado();
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          trabajoId: 't1',
          presupuestoId: 'p1',
          titulo: 'Factura cambio de grifo',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Grifo nuevo',
              cantidad: 1,
              precioUnitario: 45,
            ),
          ],
          creadaEl: DateTime(2026, 1, 2),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      // FilledButton.icon() construye un _FilledButtonWithIcon (subclase
      // privada de FilledButton), así que find.widgetWithText(FilledButton,
      // ...) no lo encuentra -- se toca directamente el texto, igual que
      // en el resto de la suite.
      await _scrollHasta(tester, find.text('Emitir factura'));
      await tester.tap(find.text('Emitir factura'));
      await tester.pumpAndSettle();
      // Primero se abre el selector de fecha de vencimiento (opcional) --
      // se cancela para dejarla sin fijar, y entonces aparece el diálogo
      // de confirmación de emisión. Este test no configura el
      // MaterialApp con locale es_ES (como sí hace main.dart), así que
      // el selector de fecha integrado de Flutter cae al inglés por
      // defecto -- de ahí 'Cancel' en vez de 'Cancelar'.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();

      expect(appData.facturas.byId('f1')!.estado, EstadoFactura.emitida);
      expect(etiquetaFactura(appData.facturas.byId('f1')!), 'Pendiente de cobro');
      // El botón real de la pantalla (no una llamada directa al
      // repositorio) debe fijar también la instantánea del cliente
      // (iteración 7.1/7.2) -- este es el único punto de la suite que
      // comprueba ese wiring end-to-end en vez de solo en el servicio o
      // el repositorio por separado.
      expect(appData.facturas.byId('f1')!.datosCliente?.nombre, 'Ana Pérez');

      // Total = 45 * 1.21 = 54.45. Cobro parcial de 20.
      await _scrollHasta(tester, find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe recibido (€) *'),
        '20',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();

      expect(appData.facturas.byId('f1')!.totalCobrado, 20);
      expect(etiquetaFactura(appData.facturas.byId('f1')!), 'Pago parcial');

      // Cobro del resto -- el campo ya viene precargado con el saldo
      // pendiente exacto (34.45), así que basta con confirmar.
      await _scrollHasta(tester, find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();

      final factura = appData.facturas.byId('f1')!;
      expect(factura.saldoPendiente, 0);
      expect(factura.pagadaCompleta, isTrue);
      expect(factura.pagos, hasLength(2));
      expect(etiquetaFactura(factura), 'Pagada');
      // Una vez pagada, ya no se ofrece registrar otro cobro.
      expect(find.widgetWithText(OutlinedButton, 'Registrar cobro'), findsNothing);
    },
  );

  testWidgets(
    'el formulario de cobro rechaza un importe mayor que el saldo '
    'pendiente sin registrar nada',
    (tester) async {
      final appData = await _appDataConTrabajoTerminado();
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura cambio de grifo',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Grifo nuevo',
              cantidad: 1,
              precioUnitario: 45,
            ),
          ],
          creadaEl: DateTime(2026, 1, 2),
        ),
      );
      await appData.facturas.emitir('f1', datosEmisor: _datosNegocioCompletos);

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe recibido (€) *'),
        '999',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no puede superar el saldo pendiente'), findsOneWidget);
      expect(appData.facturas.byId('f1')!.pagos, isEmpty);
    },
  );

  testWidgets(
    'un doble toque en "Registrar cobro" no registra el pago dos veces',
    (tester) async {
      final appData = await _appDataConTrabajoTerminado();
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura cambio de grifo',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Grifo nuevo',
              cantidad: 1,
              precioUnitario: 45,
            ),
          ],
          creadaEl: DateTime(2026, 1, 2),
        ),
      );
      await appData.facturas.emitir('f1', datosEmisor: _datosNegocioCompletos);

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Registrar cobro'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe recibido (€) *'),
        '10',
      );

      final boton = find.widgetWithText(FilledButton, 'Registrar cobro');
      // Dos toques seguidos, sin esperar entre medias a que termine el
      // primero -- el segundo debe encontrar el botón ya deshabilitado
      // (warnIfMissed: false porque, si el primer toque ya lo deshabilitó
      // y desplazó, es justo lo que se está comprobando: que el segundo
      // no haga nada, acierte o no el hit-test exacto).
      await tester.tap(boton, warnIfMissed: false);
      await tester.tap(boton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(appData.facturas.byId('f1')!.pagos, hasLength(1));
      expect(appData.facturas.byId('f1')!.totalCobrado, 10);
    },
  );

  testWidgets(
    'no rompe la app si el cliente de la factura ya no existe',
    (tester) async {
      final appData = await _appDataConTrabajoTerminado();
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'cliente-que-no-existe',
          titulo: 'Factura huérfana',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio',
              cantidad: 1,
              precioUnitario: 10,
            ),
          ],
          creadaEl: DateTime(2026, 1, 2),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(appData: appData, facturaId: 'f1')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cliente eliminado'), findsOneWidget);
    },
  );
}
