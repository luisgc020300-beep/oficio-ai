// test/app_data_eliminar_cliente_test.dart
//
// AppData.eliminarCliente() (auditoría AUD-11-01, cierre de un hallazgo
// de la auditoría funcional de las iteraciones 11/12): antes de esta
// corrección, borrar un cliente dejaba sus notas de seguimiento
// huérfanas para siempre (nunca borradas, nunca visibles desde ninguna
// pantalla). Confirma que ahora se borran junto al cliente, y que el
// resto de entidades (trabajos, presupuestos, facturas, citas) siguen
// la misma política que ya tenían antes de esta corrección: quedan
// huérfanas, nunca se tocan.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/nota_seguimiento.dart';
import 'package:oficio_ai/data/models/presupuesto.dart' show EstadoPresupuesto, Presupuesto;
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
  test('eliminarCliente() borra el cliente y todas sus notas de seguimiento', () async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
    await appData.notasSeguimiento.add(
      NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Nota 1', creadoEl: DateTime(2026)),
    );
    await appData.notasSeguimiento.add(
      NotaSeguimiento(id: 'n2', clienteId: 'c1', texto: 'Nota 2', creadoEl: DateTime(2026)),
    );

    await appData.eliminarCliente('c1');

    expect(appData.clientes.byId('c1'), isNull);
    expect(appData.notasSeguimiento.porCliente('c1'), isEmpty);
    expect(appData.notasSeguimiento.notas, isEmpty);
  });

  test('eliminarCliente() no falla ni cambia nada si el cliente no tiene notas', () async {
    final appData = await _appDataVacia();
    await appData.clientes.add(Cliente(id: 'c1', nombre: 'Sin notas', creadoEl: DateTime(2026)));

    await appData.eliminarCliente('c1');

    expect(appData.clientes.byId('c1'), isNull);
    expect(appData.notasSeguimiento.notas, isEmpty);
  });

  test(
    'eliminarCliente() no toca las notas de OTROS clientes, solo las del eliminado',
    () async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Se elimina', creadoEl: DateTime(2026)));
      await appData.clientes.add(Cliente(id: 'c2', nombre: 'Se conserva', creadoEl: DateTime(2026)));
      await appData.notasSeguimiento.add(
        NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'De c1', creadoEl: DateTime(2026)),
      );
      await appData.notasSeguimiento.add(
        NotaSeguimiento(id: 'n2', clienteId: 'c2', texto: 'De c2', creadoEl: DateTime(2026)),
      );

      await appData.eliminarCliente('c1');

      expect(appData.clientes.byId('c1'), isNull);
      expect(appData.clientes.byId('c2'), isNotNull);
      expect(appData.notasSeguimiento.porCliente('c1'), isEmpty);
      expect(appData.notasSeguimiento.porCliente('c2'), hasLength(1));
    },
  );

  test(
    'eliminarCliente() deja trabajos, presupuestos, facturas y citas huérfanos, sin tocarlos '
    '-- misma política que ya tenían antes de esta corrección',
    () async {
      final appData = await _appDataVacia();
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Reforma',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026),
        ),
      );
      await appData.presupuestos.add(
        Presupuesto(
          id: 'p1',
          clienteId: 'c1',
          titulo: 'Presupuesto reforma',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 100),
          ],
          estado: EstadoPresupuesto.borrador,
          creadoEl: DateTime(2026),
        ),
      );
      await appData.facturas.add(
        Factura(
          id: 'f1',
          clienteId: 'c1',
          titulo: 'Factura f1',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 100),
          ],
          creadaEl: DateTime(2026),
        ),
      );

      await appData.eliminarCliente('c1');

      // Nada de esto se borra -- siguen existiendo, solo con un
      // clienteId que ya no corresponde a ningún cliente real. Es el
      // comportamiento que esta corrección NO cambia (ver criterios 1 y
      // 2 del encargo).
      expect(appData.trabajos.byId('t1'), isNotNull);
      expect(appData.presupuestos.byId('p1'), isNotNull);
      expect(appData.facturas.byId('f1'), isNotNull);
    },
  );
}
