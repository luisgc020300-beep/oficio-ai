// test/flujo_integration_test.dart
//
// Pruebas dirigidas por la interfaz del flujo presupuesto -> trabajo ->
// cita (encargo, sección 8, puntos 2, 3, 5, 6, 7, 11).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/calendar/appointment_form_sheet.dart';
import 'package:oficio_ai/features/dashboard/dashboard_screen.dart';
import 'package:oficio_ai/features/jobs/job_form_sheet.dart';
import 'package:oficio_ai/features/quotes/quote_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppData> _appDataConCliente() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final appData = AppData(store);
  await Future.wait([
    appData.clientes.load(),
    appData.trabajos.load(),
    appData.presupuestos.load(),
    appData.citas.load(),
  ]);
  await appData.clientes.add(
    Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)),
  );
  return appData;
}

Presupuesto _presupuesto(EstadoPresupuesto estado) => Presupuesto(
  id: 'p1',
  clienteId: 'c1',
  titulo: 'Cambio de grifo',
  conceptos: const [
    ConceptoPresupuesto(
      id: 'co1',
      descripcion: 'Grifo',
      cantidad: 1,
      precioUnitario: 45,
    ),
  ],
  estado: estado,
  creadoEl: DateTime(2026, 1, 1),
);

void main() {
  // QuoteDetailScreen y DashboardScreen formatean fechas con DateFormat
  // (es_ES) -- sin esto, cualquier test que los pinte lanza
  // "Locale data has not been initialized".
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('2. Un presupuesto en borrador no ofrece crear trabajo', () {
    testWidgets('sin el botón "Crear trabajo" en borrador', (tester) async {
      final appData = await _appDataConCliente();
      await appData.presupuestos.add(_presupuesto(EstadoPresupuesto.borrador));

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteDetailScreen(appData: appData, presupuestoId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crear trabajo'), findsNothing);
    });

    testWidgets('sí aparece el botón "Crear trabajo" en aceptado sin trabajo', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await appData.presupuestos.add(_presupuesto(EstadoPresupuesto.aceptado));

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteDetailScreen(appData: appData, presupuestoId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crear trabajo'), findsOneWidget);
    });
  });

  group('3. Crear un trabajo reutiliza el cliente y los datos del presupuesto', () {
    testWidgets('el trabajo creado queda con el mismo cliente y título sugerido', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await appData.presupuestos.add(_presupuesto(EstadoPresupuesto.aceptado));

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteDetailScreen(appData: appData, presupuestoId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear trabajo'));
      await tester.pumpAndSettle();

      // Ahora hay dos widgets con el texto "Crear trabajo": el botón de
      // la ficha del presupuesto (detrás) y el de guardar del formulario
      // (en la hoja modal, encima) -- se pulsa el de la hoja.
      final botonGuardar = find.text('Crear trabajo').last;
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(appData.trabajos.trabajos, hasLength(1));
      final trabajo = appData.trabajos.trabajos.first;
      expect(trabajo.clienteId, 'c1');
      expect(trabajo.titulo, 'Cambio de grifo');
      expect(trabajo.presupuestoId, 'p1');
      expect(trabajo.estado.name, 'pendiente');
    });
  });

  group('5. No se puede duplicar el trabajo de un presupuesto', () {
    testWidgets('la ficha del presupuesto ofrece abrir el trabajo, no crear otro', (
      tester,
    ) async {
      final appData = await _appDataConCliente();
      await appData.presupuestos.add(_presupuesto(EstadoPresupuesto.aceptado));
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 2),
          presupuestoId: 'p1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteDetailScreen(appData: appData, presupuestoId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crear trabajo'), findsNothing);
      expect(find.text('Ya tiene un trabajo creado'), findsOneWidget);
    });

    testWidgets(
      'mostrarFormularioTrabajo con presupuestoIdFijo ya usado no crea un segundo',
      (tester) async {
        final appData = await _appDataConCliente();
        await appData.trabajos.add(
          Trabajo(
            id: 't1',
            clienteId: 'c1',
            titulo: 'Cambio de grifo',
            estado: EstadoTrabajo.pendiente,
            creadoEl: DateTime(2026, 1, 2),
            presupuestoId: 'p1',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => mostrarFormularioTrabajo(
                    context,
                    appData: appData,
                    clienteId: 'c1',
                    presupuestoIdFijo: 'p1',
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        // No se ha abierto ningún formulario nuevo (el guardia actúa
        // antes de mostrar la hoja) y sigue habiendo un único trabajo.
        expect(find.text('Nuevo trabajo'), findsNothing);
        expect(appData.trabajos.trabajos, hasLength(1));
      },
    );
  });

  group('6. Cancelar el formulario de trabajo no guarda nada', () {
    testWidgets('abrir el formulario sin confirmar no crea ningún trabajo', (
      tester,
    ) async {
      final appData = await _appDataConCliente();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => mostrarFormularioTrabajo(
                  context,
                  appData: appData,
                  clienteId: 'c1',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo trabajo'), findsOneWidget);
      expect(appData.trabajos.trabajos, isEmpty);

      // Cierra tocando fuera de la hoja (el scrim del modal) en vez de
      // guardar.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(appData.trabajos.trabajos, isEmpty);
    });
  });

  group('7. Programar una cita guarda fecha, duración y referencias', () {
    testWidgets('la cita creada queda con cliente, trabajo y duración correctos', (
      tester,
    ) async {
      final appData = await _appDataConCliente();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => mostrarFormularioCita(
                  context,
                  appData: appData,
                  clienteIdFijo: 'c1',
                  trabajoIdFijo: 't1',
                  tituloInicial: 'Visita técnica',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva cita'), findsOneWidget);
      expect(appData.citas.citas, isEmpty);

      await tester.tap(find.text('Crear cita'));
      await tester.pumpAndSettle();

      expect(appData.citas.citas, hasLength(1));
      final cita = appData.citas.citas.first;
      expect(cita.titulo, 'Visita técnica');
      expect(cita.clienteId, 'c1');
      expect(cita.trabajoId, 't1');
      expect(cita.duracionMinutos, 60);
    });
  });

  group('11. El dashboard refleja los cambios de estado', () {
    testWidgets(
      '"Aceptados sin trabajo creado" baja a 0 en cuanto se crea el trabajo',
      (tester) async {
        final appData = await _appDataConCliente();
        await appData.presupuestos.add(_presupuesto(EstadoPresupuesto.aceptado));

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardScreen(
              appData: appData,
              onVerTrabajos: () {},
              onVerPresupuestos: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aceptados sin trabajo creado'), findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Aceptados sin trabajo creado'),
              matching: find.byType(Card),
            ),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );

        await appData.trabajos.add(
          Trabajo(
            id: 't1',
            clienteId: 'c1',
            titulo: 'Cambio de grifo',
            estado: EstadoTrabajo.pendiente,
            creadoEl: DateTime(2026, 1, 2),
            presupuestoId: 'p1',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Aceptados sin trabajo creado'),
              matching: find.byType(Card),
            ),
            matching: find.text('0'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
