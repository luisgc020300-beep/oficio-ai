// test/assisted_quote_integration_test.dart
//
// Integración del flujo asistido con los datos reales de la app: genera
// una propuesta con el motor local, la lleva a la MISMA pantalla de
// revisión que usa la creación manual (QuoteFormScreen), confirma el
// guardado y comprueba que queda bien persistida en el repositorio
// existente -- cliente vinculado, estado borrador, esDemo correcto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/assistant/local_quote_generator.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/features/quotes/quote_form_screen.dart';
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
  ]);
  return appData;
}

void main() {
  testWidgets(
    'un borrador generado y confirmado se guarda en el repositorio, con cliente y esDemo correctos',
    (tester) async {
      final appData = await _appDataVacia();
      final cliente = Cliente(
        id: 'c1',
        nombre: 'Ana Pérez',
        creadoEl: DateTime(2026),
      );
      await appData.clientes.add(cliente);

      final propuesta = await LocalQuoteGenerator().generar(
        'Cambiar el grifo de la cocina',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuoteFormScreen(
            appData: appData,
            clienteIdFijo: cliente.id,
            tituloInicial: propuesta.tituloSugerido,
            conceptosIniciales: propuesta.conceptos,
            avisoGeneracion: propuesta.mensaje,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El aviso de que es una sugerencia del motor local es visible.
      expect(find.textContaining('He reconocido'), findsOneWidget);
      expect(appData.presupuestos.presupuestos, isEmpty);

      await tester.tap(find.text('Crear presupuesto'));
      await tester.pumpAndSettle();

      // Confirmación previa al guardado (sección 4 del encargo).
      expect(find.text('¿Guardar este presupuesto?'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(appData.presupuestos.presupuestos, hasLength(1));
      final guardado = appData.presupuestos.presupuestos.first;
      expect(guardado.clienteId, 'c1');
      expect(guardado.estado, EstadoPresupuesto.borrador);
      expect(guardado.esDemo, isFalse);
      expect(guardado.conceptos, isNotEmpty);
      expect(guardado.titulo, propuesta.tituloSugerido);
      expect(guardado.totales.total, greaterThan(0));
    },
  );

  testWidgets('cancelar la confirmación no guarda nada', (tester) async {
    final appData = await _appDataVacia();
    final cliente = Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026));
    await appData.clientes.add(cliente);
    final propuesta = await LocalQuoteGenerator().generar('Revisar una fuga en el baño');

    await tester.pumpWidget(
      MaterialApp(
        home: QuoteFormScreen(
          appData: appData,
          clienteIdFijo: cliente.id,
          tituloInicial: propuesta.tituloSugerido,
          conceptosIniciales: propuesta.conceptos,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear presupuesto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir revisando'));
    await tester.pumpAndSettle();

    expect(appData.presupuestos.presupuestos, isEmpty);
    // Seguimos en la pantalla de revisión, no se ha navegado fuera.
    expect(find.text('Nuevo presupuesto'), findsOneWidget);
  });
}
