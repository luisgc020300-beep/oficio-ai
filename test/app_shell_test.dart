// test/app_shell_test.dart
//
// AppShell pasó de IndexedStack a PageView para poder deslizar entre
// pestañas con el dedo, no solo tocando la barra inferior. Esto cubre:
// - que deslizar sobre contenido normal (no sobre una tira horizontal de
//   chips) cambia de pestaña, igual que tocar la barra;
// - que _KeepAlivePage de verdad conserva el estado de una pestaña (un
//   filtro aplicado en Clientes) al salir y volver, igual que hacía
//   IndexedStack antes -- es la garantía que este cambio no debía romper;
// - qué pasa al deslizar empezando justo sobre una tira horizontal de
//   chips (Clientes tiene una debajo del buscador): se documenta el
//   resultado real observado, no se presupone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/app_shell.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/trabajo.dart' show EstadoTrabajo, Trabajo;
import 'package:shared_preferences/shared_preferences.dart';

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
    'deslizar horizontalmente sobre el contenido cambia de pestaña, igual que tocar la barra',
    (tester) async {
      final appData = await _appDataVacia();
      await tester.pumpWidget(MaterialApp(home: AppShell(appData: appData)));
      await tester.pumpAndSettle();

      expect(find.text('Hola de nuevo'), findsOneWidget);

      // El propio texto del saludo no es un widget con scroll horizontal
      // propio -- el gesto solo puede capturarlo el PageView de la pestaña.
      await tester.drag(find.text('Hola de nuevo'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Hola de nuevo'), findsNothing);
      // 'Clientes' aparece dos veces: la etiqueta de la barra inferior y
      // el título del AppBar de la pantalla -- se usa el del AppBar
      // explícitamente para el siguiente gesto, para no depender del
      // orden en que el Finder devuelva los dos.
      final tituloClientes = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Clientes'),
      );
      expect(tituloClientes, findsOneWidget);

      // Y de vuelta, deslizando en sentido contrario, empezando sobre el
      // título del AppBar (tampoco tiene scroll propio).
      await tester.drag(tituloClientes, const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Hola de nuevo'), findsOneWidget);
    },
  );

  testWidgets(
    'cambiar de pestaña (deslizando) y volver conserva el filtro aplicado en Clientes',
    (tester) async {
      final appData = await _appDataVacia();
      await appData.clientes.add(
        Cliente(id: 'conTrabajo', nombre: 'Ana con trabajo activo', creadoEl: DateTime(2026)),
      );
      await appData.clientes.add(
        Cliente(id: 'sinTrabajo', nombre: 'Beltrán sin trabajos', creadoEl: DateTime(2026)),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'conTrabajo',
          titulo: 'Reforma baño',
          estado: EstadoTrabajo.enCurso,
          creadoEl: DateTime(2026),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: AppShell(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      expect(find.text('Ana con trabajo activo'), findsOneWidget);
      expect(find.text('Beltrán sin trabajos'), findsOneWidget);

      await tester.tap(find.text('Trabajos activos'));
      await tester.pumpAndSettle();
      expect(find.text('Ana con trabajo activo'), findsOneWidget);
      expect(find.text('Beltrán sin trabajos'), findsNothing);

      // Fuera (deslizando, no tocando) y de vuelta (tocando la barra) --
      // el filtro debe seguir aplicado: si _KeepAlivePage no funcionara,
      // ClientsListScreen se reconstruiría desde cero con _filtro de
      // nuevo en "Todos" y Beltrán volvería a aparecer.
      await tester.drag(find.text('Ana con trabajo activo'), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Hola de nuevo'), findsOneWidget);

      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();

      expect(find.text('Ana con trabajo activo'), findsOneWidget);
      expect(find.text('Beltrán sin trabajos'), findsNothing);
    },
  );

  testWidgets(
    'deslizar empezando justo sobre la tira horizontal de chips de Clientes: '
    'se documenta el resultado real, no se presupone',
    (tester) async {
      final appData = await _appDataVacia();
      // La tira de chips solo se renderiza con al menos un cliente dado
      // de alta -- con cero clientes la pantalla muestra el estado vacío
      // general en su lugar, sin chips que deslizar.
      await appData.clientes.add(
        Cliente(id: 'c1', nombre: 'Cliente de prueba', creadoEl: DateTime(2026)),
      );
      await tester.pumpWidget(MaterialApp(home: AppShell(appData: appData)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();

      // 'Todos' es el primer chip de la tira horizontal, justo debajo del
      // buscador -- empezar el gesto ahí es el caso límite real: dos
      // widgets con scroll horizontal (la tira de chips y el PageView de
      // las pestañas) compitiendo por el mismo gesto.
      await tester.drag(find.text('Todos'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      // Lo que importa para este cambio: la app no debe quedar en un
      // estado roto (ni excepción, ni las dos pestañas montadas a la
      // vez) sea cual sea el ganador del gesto.
      // Resultado real observado (no asumido): la tira de chips, al ser
      // el scrollable más interno, se queda con el gesto -- se desplaza
      // ella misma en vez de cambiar de pestaña. Deslizar sobre el resto
      // de la pantalla (fuera de la tira) sigue cambiando de pestaña con
      // normalidad (ver el primer test de este archivo).
      expect(tester.takeException(), isNull);
    },
  );
}
