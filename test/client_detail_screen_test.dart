// test/client_detail_screen_test.dart
//
// Ficha de cliente (iteración 11): historial económico (con
// rectificativas y facturas anuladas, mismo criterio que la
// rentabilidad de un trabajo -- valores calculados aquí a mano, nunca
// copiados de client_detail_screen.dart), clientes sin actividad,
// notas y seguimientos desde la UI, y navegación a los flujos
// existentes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/core/utils/formatters.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/nota_seguimiento.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/clients/client_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Factura _facturaOrdinaria({
  required String id,
  required String clienteId,
  required double precio,
}) => Factura(
  id: id,
  clienteId: clienteId,
  titulo: 'Factura $id',
  conceptos: [
    ConceptoPresupuesto(id: 'c1', descripcion: 'Servicio', cantidad: 1, precioUnitario: precio),
  ],
  creadaEl: DateTime(2026, 1, 1),
);

// La ficha es un ListView largo -- más allá del viewport de 600dp del
// test, el contenido ni siquiera llega a construirse (mismo motivo que
// en job_rentabilidad_test.dart), así que hay que desplazarse hasta él
// antes de buscarlo o tocarlo.
Future<void> _scrollHasta(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  // El scroll final (Scrollable.ensureVisible) es animado -- sin este
  // pump, un tap inmediato después puede fallar el hit test porque la
  // animación todavía no ha terminado.
  await tester.pumpAndSettle();
}

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

  testWidgets(
    'historial económico: factura parcialmente cobrada, otra cobrada, una anulada y una '
    'rectificativa -- el total nunca cuenta dos veces ni incluye lo anulado',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      // f1: 200 + 21% = 242, cobrada parcialmente (100).
      await appData.facturas.add(_facturaOrdinaria(id: 'f1', clienteId: 'c1', precio: 200));
      final f1 = await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f1', fecha: DateTime(2026, 2, 1), importe: 100);

      // f2: 100 + 21% = 121, cobrada en su totalidad.
      await appData.facturas.add(_facturaOrdinaria(id: 'f2', clienteId: 'c1', precio: 100));
      await appData.facturas.emitir('f2', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f2', fecha: DateTime(2026, 2, 2), importe: 121);

      // f3: 50 + 21% = 60,50, pero ANULADA -- no debe contar en nada.
      await appData.facturas.add(_facturaOrdinaria(id: 'f3', clienteId: 'c1', precio: 50));
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
          creadaEl: DateTime(2026, 2, 5),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: f1.id,
          motivoRectificacion: 'Cantidad facturada por error',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      await appData.facturas.emitir('r1', datosEmisor: _datosCompletos);

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      // Cálculo independiente, no tomado del código de producción:
      // Facturado = 242 (f1) + 121 (f2) + (-24,20) (r1) = 338,80
      // Cobrado   = 100 (f1) + 121 (f2) = 221,00
      // Pendiente = (242-100) (f1) + (121-121) (f2) + 0 (r1) = 142,00
      expect(find.text('Historial económico'), findsOneWidget);
      expect(find.text(formatCurrency(338.8)), findsWidgets); // Facturado
      expect(find.text(formatCurrency(221.0)), findsWidgets); // Cobrado
      expect(find.text(formatCurrency(142.0)), findsWidgets); // Pendiente de cobro

      // Control negativo: el importe de la factura anulada no debe
      // aparecer como si contara en el total.
      expect(find.text(formatCurrency(60.5)), findsNothing);
    },
  );

  // Auditoría AUD-12-06: el test anterior solo usa la modalidad "por
  // diferencias" -- esta cubre "importe resultante", la más propensa a
  // doble contabilización (ver Factura.importeFacturacion). Escenario
  // numérico idéntico al ya verificado en
  // rectificativa_calculos_test.dart (test 1): original 100€+21%=121€,
  // corregida a 80€+21%=96,80€, importeRectificacion=-24,20€.
  testWidgets(
    'historial económico: una rectificativa "importe resultante" no duplica el importe de la '
    'factura original',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      await appData.facturas.add(_facturaOrdinaria(id: 'o', clienteId: 'c1', precio: 100));
      final original = await appData.facturas.emitir('o', datosEmisor: _datosCompletos);
      expect(original.totales.total, 121); // control del punto de partida, igual que en el modelo

      await appData.facturas.add(
        Factura(
          id: 'r',
          clienteId: 'c1',
          titulo: 'Rectificativa de o',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'Corrección', cantidad: 1, precioUnitario: 80),
          ],
          creadaEl: DateTime(2026, 2, 5),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Precio pactado inferior al facturado',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await appData.facturas.emitir('r', datosEmisor: _datosCompletos);
      expect(appData.facturas.byId('r')!.importeRectificacion, closeTo(-24.2, 0.001));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      // Facturado = 121 (original) + (-24,20) (rectificativa, usando
      // importeRectificacion, no su totales.total de 96,80) = 96,80.
      expect(find.text(formatCurrency(96.8)), findsWidgets);
      // Control negativo: si el código usara por error totales.total de
      // la rectificativa en vez de importeRectificacion, el total
      // mostrado sería 121+96,80=217,80 -- no debe aparecer nunca.
      expect(find.text(formatCurrency(217.8)), findsNothing);
    },
  );

  testWidgets(
    'un cliente sin trabajos, presupuestos, facturas ni notas no muestra historial económico '
    'y ofrece el estado vacío general',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Sin actividad', creadoEl: DateTime(2026)));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial económico'), findsNothing);
      expect(find.text('Seguimientos pendientes'), findsNothing);
      expect(find.text('Sin trabajos todavía.'), findsOneWidget);
      expect(find.text('Sin presupuestos todavía.'), findsOneWidget);
      await _scrollHasta(tester, find.text('Sin actividad todavía'));
      expect(find.text('Sin facturas todavía.'), findsOneWidget);
      expect(find.text('Sin notas todavía.'), findsOneWidget);
      expect(find.text('Sin actividad todavía'), findsOneWidget);
    },
  );

  testWidgets(
    'navegación: tocar un trabajo, un presupuesto y una factura del cliente abre su detalle',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Reforma de baño',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p1',
          clienteId: 'c1',
          titulo: 'Presupuesto reforma',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'Mano de obra', cantidad: 1, precioUnitario: 100),
          ],
          estado: EstadoPresupuesto.enviado,
          creadoEl: DateTime(2026, 1, 2),
        ),
      );
      await appData.facturas.add(_facturaOrdinaria(id: 'f1', clienteId: 'c1', precio: 100));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reforma de baño'));
      await tester.pumpAndSettle();
      expect(find.text('Reforma de baño'), findsWidgets); // AppBar del detalle del trabajo
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Presupuesto reforma'));
      await tester.pumpAndSettle();
      expect(find.text('Presupuesto reforma'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Factura f1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Factura f1'));
      await tester.pumpAndSettle();
      expect(find.text('Factura f1'), findsWidgets);
    },
  );

  testWidgets(
    'acciones rápidas: "Trabajo" abre el formulario de trabajo ya con este cliente, '
    '"Presupuesto" abre la pantalla de nuevo presupuesto',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'Trabajo').first);
      await tester.pumpAndSettle();
      expect(find.text('Nuevo trabajo'), findsOneWidget);
      // Cierra la hoja modal tocando fuera (la barrera cubre el resto de
      // la pantalla) para volver a la ficha del cliente.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'Presupuesto').first);
      await tester.pumpAndSettle();
      expect(find.text('Nuevo presupuesto'), findsOneWidget);
    },
  );

  group('notas y seguimiento', () {
    testWidgets('"Nota" crea una nota y aparece en el historial', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'Nota').first);
      await tester.pumpAndSettle();
      expect(find.text('Nueva nota'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nota *'), 'Pidió revisar el precio');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar nota'));
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Pidió revisar el precio'));
      expect(find.text('Pidió revisar el precio'), findsOneWidget);
      expect(appData.notasSeguimiento.porCliente('c1'), hasLength(1));
    });

    testWidgets('una nota sin texto no se guarda -- la validación lo impide', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Nota').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar nota'));
      await tester.pumpAndSettle();

      expect(find.text('Obligatorio'), findsOneWidget);
      expect(appData.notasSeguimiento.porCliente('c1'), isEmpty);
    });

    testWidgets('eliminar una nota exige confirmación', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.notasSeguimiento.add(
        NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Para borrar', creadoEl: DateTime(2026)),
      );

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();
      await _scrollHasta(tester, find.byTooltip('Eliminar nota'));

      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta nota?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(appData.notasSeguimiento.porCliente('c1'), hasLength(1));

      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(appData.notasSeguimiento.porCliente('c1'), isEmpty);
    });

    testWidgets(
      '"Seguimiento" programa una nota con fecha; se clasifica en atrasados/hoy/futuros y se '
      'puede marcar realizado o cancelado manualmente',
      (tester) async {
        final appData = await _appDataVacia();
        await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
        // Seguimiento ya vencido (atrasado) y uno de hoy, creados
        // directamente en el repositorio para controlar la fecha exacta
        // -- el datepicker de la UI no permite fijar una fecha pasada
        // concreta de forma fiable en un test.
        final hoy = DateTime.now();
        await appData.notasSeguimiento.add(
          NotaSeguimiento(
            id: 'atrasada',
            clienteId: 'c1',
            texto: 'Llamar para cerrar presupuesto',
            creadoEl: hoy.subtract(const Duration(days: 3)),
            fechaSeguimiento: hoy.subtract(const Duration(days: 3)),
          ),
        );
        await appData.notasSeguimiento.add(
          NotaSeguimiento(
            id: 'hoy',
            clienteId: 'c1',
            texto: 'Enviar factura',
            creadoEl: hoy,
            fechaSeguimiento: DateTime(hoy.year, hoy.month, hoy.day, 9),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Seguimientos pendientes'), findsOneWidget);
        expect(find.text('Atrasado'), findsOneWidget);
        expect(find.text('Hoy'), findsOneWidget);

        // Marca como realizado el primero que aparece (el atrasado, por
        // ir primero en la agrupación atrasados->hoy->futuros).
        await tester.tap(find.byTooltip('Marcar como realizado').first);
        await tester.pumpAndSettle();
        expect(appData.notasSeguimiento.byId('atrasada')!.estadoSeguimiento, EstadoSeguimiento.realizado);
        expect(find.text('Atrasado'), findsNothing);

        await tester.tap(find.byTooltip('Cancelar seguimiento').first);
        await tester.pumpAndSettle();
        expect(appData.notasSeguimiento.byId('hoy')!.estadoSeguimiento, EstadoSeguimiento.cancelado);
        expect(find.text('Seguimientos pendientes'), findsNothing);
      },
    );

    // Caso que faltaba del test anterior (auditoría AUD-11-03, iteración
    // de correcciones): un seguimiento con fecha futura -- el otro test
    // ya cubre atrasado/hoy/realizado/cancelado, no se duplica aquí.
    testWidgets(
      'un seguimiento con fecha futura se clasifica como pendiente, sin mezclarse con los '
      'atrasados o de hoy',
      (tester) async {
        final appData = await _appDataVacia();
        await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
        final hoy = DateTime.now();
        await appData.notasSeguimiento.add(
          NotaSeguimiento(
            id: 'futura',
            clienteId: 'c1',
            texto: 'Volver a llamar la semana que viene',
            creadoEl: hoy,
            fechaSeguimiento: hoy.add(const Duration(days: 7)),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Seguimientos pendientes'), findsOneWidget);
        expect(find.text('Atrasado'), findsNothing);
        expect(find.text('Hoy'), findsNothing);
        await _scrollHasta(tester, find.text('Volver a llamar la semana que viene'));
        expect(find.text('Volver a llamar la semana que viene'), findsOneWidget);
      },
    );
  });

  // Auditoría AUD-11-02: la ficha pasó de mostrar solo "próxima cita" (una
  // línea) a una sección "Citas" con lo próximo y lo anterior del
  // cliente.
  group('citas', () {
    testWidgets('un cliente sin citas muestra el estado vacío de la sección', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Sin citas', creadoEl: DateTime(2026)));

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();

      await _scrollHasta(tester, find.text('Citas'));
      expect(find.text('Sin citas todavía.'), findsOneWidget);
    });

    testWidgets(
      'con una cita futura, una pasada sin completar y una completada, se agrupan en '
      '"Próximas" y "Anteriores" sin mezclar las de otro cliente',
      (tester) async {
        final appData = await _appDataVacia();
        await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
        await appData.clientes.add(Cliente(id: 'c2', nombre: 'Otro cliente', creadoEl: DateTime(2026)));
        final hoy = DateTime.now();

        await appData.citas.add(
          Cita(id: 'futura', titulo: 'Revisión futura', fechaHora: hoy.add(const Duration(days: 5)), clienteId: 'c1'),
        );
        await appData.citas.add(
          Cita(
            id: 'pasada',
            titulo: 'Visita pasada sin marcar',
            fechaHora: hoy.subtract(const Duration(days: 10)),
            clienteId: 'c1',
          ),
        );
        await appData.citas.add(
          Cita(
            id: 'completada',
            titulo: 'Instalación ya hecha',
            fechaHora: hoy.subtract(const Duration(days: 20)),
            clienteId: 'c1',
            completada: true,
          ),
        );
        // De otro cliente -- nunca debe aparecer en la ficha de c1.
        await appData.citas.add(
          Cita(id: 'ajena', titulo: 'Cita de otro cliente', fechaHora: hoy.add(const Duration(days: 1)), clienteId: 'c2'),
        );

        await tester.pumpWidget(
          MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
        );
        await tester.pumpAndSettle();
        await _scrollHasta(tester, find.text('Citas'));

        expect(find.text('Próximas'), findsOneWidget);
        expect(find.text('Anteriores'), findsOneWidget);
        expect(find.text('Revisión futura'), findsOneWidget);
        expect(find.text('Visita pasada sin marcar'), findsOneWidget);
        expect(find.text('Instalación ya hecha'), findsOneWidget);
        expect(find.text('Cita de otro cliente'), findsNothing);

        // Orden dentro de "Anteriores": más reciente primero -- la
        // pasada sin completar (hace 10 días) antes que la completada
        // (hace 20 días).
        final posicionPasada = tester.getTopLeft(find.text('Visita pasada sin marcar')).dy;
        final posicionCompletada = tester.getTopLeft(find.text('Instalación ya hecha')).dy;
        expect(posicionPasada, lessThan(posicionCompletada));
      },
    );

    testWidgets('tocar una cita abre el mismo formulario de edición que usa la agenda', (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.citas.add(
        Cita(
          id: 'c-futura',
          titulo: 'Revisión anual',
          fechaHora: DateTime.now().add(const Duration(days: 3)),
          clienteId: 'c1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ClientDetailScreen(appData: appData, clienteId: 'c1')),
      );
      await tester.pumpAndSettle();
      await _scrollHasta(tester, find.text('Revisión anual'));

      await tester.tap(find.text('Revisión anual'));
      await tester.pumpAndSettle();
      expect(find.text('Editar cita'), findsOneWidget);
    });
  });
}
