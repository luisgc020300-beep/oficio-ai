// test/flujo_presupuesto_trabajo_cita_test.dart
//
// Pruebas a nivel de repositorio/modelo del flujo presupuesto -> trabajo
// -> cita (encargo, sección 8, puntos 1, 4, 8, 9, 10, 12). Las pruebas
// dirigidas por UI (aceptar desde la pantalla, crear trabajo desde el
// botón, anti-duplicado en el formulario, cancelar, programar cita desde
// el formulario) están en flujo_integration_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
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

Presupuesto _presupuestoDemo({
  String id = 'p1',
  EstadoPresupuesto estado = EstadoPresupuesto.enviado,
}) => Presupuesto(
  id: id,
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
  group('1. Aceptar un presupuesto', () {
    test('cambia su estado a aceptado sin tocar conceptos ni importes', () async {
      final appData = await _appDataVacia();
      final original = _presupuestoDemo();
      await appData.presupuestos.add(original);

      await appData.presupuestos.update(
        original.copyWith(estado: EstadoPresupuesto.aceptado),
      );

      final actualizado = appData.presupuestos.byId('p1')!;
      expect(actualizado.estado, EstadoPresupuesto.aceptado);
      expect(actualizado.conceptos, original.conceptos);
      expect(actualizado.totales.total, original.totales.total);
    });
  });

  group('4 y 9. Relación trabajo -> presupuesto', () {
    test('crear un trabajo no modifica el presupuesto original', () async {
      final appData = await _appDataVacia();
      final presupuesto = _presupuestoDemo(estado: EstadoPresupuesto.aceptado);
      await appData.presupuestos.add(presupuesto);

      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: presupuesto.clienteId,
          titulo: presupuesto.titulo,
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 2),
          presupuestoId: presupuesto.id,
        ),
      );

      final presupuestoTrasCrear = appData.presupuestos.byId('p1')!;
      expect(presupuestoTrasCrear.estado, presupuesto.estado);
      expect(presupuestoTrasCrear.conceptos, presupuesto.conceptos);
      expect(presupuestoTrasCrear.titulo, presupuesto.titulo);
      // El campo trabajoId del propio presupuesto -- que ya existía antes
      // de esta iteración -- se queda tal cual estaba (null aquí):
      // la relación nueva vive solo del lado del trabajo.
      expect(presupuestoTrasCrear.trabajoId, isNull);
    });

    test('el trabajo nuevo empieza pendiente, nunca finalizado ni aceptado', () async {
      final appData = await _appDataVacia();
      final presupuesto = _presupuestoDemo(estado: EstadoPresupuesto.aceptado);
      await appData.presupuestos.add(presupuesto);

      final trabajo = Trabajo(
        id: 't1',
        clienteId: presupuesto.clienteId,
        titulo: presupuesto.titulo,
        estado: EstadoTrabajo.pendiente,
        creadoEl: DateTime(2026, 1, 2),
        presupuestoId: presupuesto.id,
      );
      await appData.trabajos.add(trabajo);

      expect(appData.trabajos.byId('t1')!.estado, EstadoTrabajo.pendiente);
    });

    test('porPresupuesto() encuentra el trabajo creado desde ese presupuesto', () async {
      final appData = await _appDataVacia();
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

      expect(appData.trabajos.porPresupuesto('p1'), hasLength(1));
      expect(appData.trabajos.porPresupuesto('otro-id'), isEmpty);
    });
  });

  group('8. Citas vinculadas a un trabajo', () {
    test('una cita con trabajoId aparece en delDia() y en porTrabajo()', () async {
      final appData = await _appDataVacia();
      final dia = DateTime(2026, 3, 10, 10, 0);
      await appData.citas.add(
        Cita(
          id: 'cita1',
          titulo: 'Visita de instalación',
          fechaHora: dia,
          duracionMinutos: 90,
          clienteId: 'c1',
          trabajoId: 't1',
        ),
      );

      expect(appData.citas.delDia(DateTime(2026, 3, 10)), hasLength(1));
      expect(appData.citas.porTrabajo('t1'), hasLength(1));
      expect(appData.citas.porTrabajo('t1').first.clienteId, 'c1');
    });
  });

  group('9. Persistencia de las relaciones', () {
    test('presupuestoId y trabajoId sobreviven a recargar los repositorios', () async {
      final appData1 = await _appDataVacia();
      await appData1.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 2),
          presupuestoId: 'p1',
        ),
      );
      await appData1.citas.add(
        Cita(
          id: 'cita1',
          titulo: 'Visita',
          fechaHora: DateTime(2026, 3, 10, 10, 0),
          trabajoId: 't1',
        ),
      );

      // Mismo almacenamiento, repositorios nuevos -- simula cerrar y
      // volver a abrir la app.
      final store = await LocalStore.open();
      final appData2 = AppData(store);
      await Future.wait([
        appData2.trabajos.load(),
        appData2.citas.load(),
      ]);

      expect(appData2.trabajos.byId('t1')!.presupuestoId, 'p1');
      expect(appData2.citas.citas.first.trabajoId, 't1');
    });
  });

  group('10. Compatibilidad con datos antiguos (sin relaciones)', () {
    test('Trabajo.fromJson sin presupuestoId se lee como null', () {
      final jsonAntiguo = {
        'id': 't1',
        'clienteId': 'c1',
        'titulo': 'Reparación',
        'estado': 'pendiente',
        'creadoEl': DateTime(2026).toIso8601String(),
        // sin 'presupuestoId' -- así se guardaba antes de vincularlo
      };
      final trabajo = Trabajo.fromJson(jsonAntiguo);
      expect(trabajo.presupuestoId, isNull);
      expect(trabajo.titulo, 'Reparación');
    });

    test('Cita.fromJson sin trabajoId se lee como null', () {
      final jsonAntiguo = {
        'id': 'cita1',
        'titulo': 'Visita',
        'fechaHora': DateTime(2026).toIso8601String(),
        // sin 'trabajoId'
      };
      final cita = Cita.fromJson(jsonAntiguo);
      expect(cita.trabajoId, isNull);
      expect(cita.titulo, 'Visita');
    });

    test(
      'un repositorio con trabajos antiguos (sin presupuestoId) y nuevos (con) carga ambos',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = await LocalStore.open();
        // Escribe directo en el almacenamiento, simulando datos guardados
        // por una versión anterior de la app.
        await store.writeList('oficio_ai.trabajos', [
          {
            'id': 'antiguo',
            'clienteId': 'c1',
            'titulo': 'Trabajo de antes',
            'estado': 'pendiente',
            'creadoEl': DateTime(2025).toIso8601String(),
          },
        ]);

        final appData = AppData(store);
        await appData.trabajos.load();

        expect(appData.trabajos.trabajos, hasLength(1));
        expect(appData.trabajos.byId('antiguo')!.presupuestoId, isNull);
      },
    );
  });

  group('Sección 7 -- sin borrados en cascada', () {
    test('eliminar un presupuesto no borra el trabajo creado desde él', () async {
      final appData = await _appDataVacia();
      final presupuesto = _presupuestoDemo(estado: EstadoPresupuesto.aceptado);
      await appData.presupuestos.add(presupuesto);
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: presupuesto.clienteId,
          titulo: presupuesto.titulo,
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 2),
          presupuestoId: presupuesto.id,
        ),
      );

      await appData.presupuestos.delete(presupuesto.id);

      expect(appData.presupuestos.byId(presupuesto.id), isNull);
      // El trabajo sigue existiendo -- solo su referencia queda
      // "huérfana" (presupuestoId apunta a un id que ya no existe), y
      // leerla con byId() devuelve null sin lanzar excepción.
      final trabajoTrasEliminar = appData.trabajos.byId('t1')!;
      expect(trabajoTrasEliminar.titulo, presupuesto.titulo);
      expect(
        appData.presupuestos.byId(trabajoTrasEliminar.presupuestoId!),
        isNull,
      );
    });

    test('eliminar un trabajo no borra sus citas programadas', () async {
      final appData = await _appDataVacia();
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Cambio de grifo',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 2),
        ),
      );
      await appData.citas.add(
        Cita(
          id: 'cita1',
          titulo: 'Visita',
          fechaHora: DateTime(2026, 3, 10, 10, 0),
          trabajoId: 't1',
        ),
      );

      await appData.trabajos.delete('t1');

      expect(appData.trabajos.byId('t1'), isNull);
      // La cita sigue existiendo -- referencia huérfana, sin excepción.
      expect(appData.citas.citas, hasLength(1));
      expect(appData.citas.citas.first.trabajoId, 't1');
      expect(() => appData.trabajos.byId(appData.citas.citas.first.trabajoId!), returnsNormally);
    });
  });

  group('12. esDemo se mantiene junto con las nuevas relaciones', () {
    test('un trabajo de ejemplo con presupuestoId conserva esDemo tras el ciclo JSON', () {
      final trabajo = Trabajo(
        id: 'demo-t1',
        clienteId: 'demo-c1',
        titulo: 'Trabajo demo',
        estado: EstadoTrabajo.enCurso,
        creadoEl: DateTime(2026),
        presupuestoId: 'demo-p1',
        esDemo: true,
      );
      final restaurado = Trabajo.fromJson(trabajo.toJson());
      expect(restaurado.esDemo, isTrue);
      expect(restaurado.presupuestoId, 'demo-p1');
    });

    test('una cita de ejemplo con trabajoId conserva esDemo tras el ciclo JSON', () {
      final cita = Cita(
        id: 'demo-cita1',
        titulo: 'Visita demo',
        fechaHora: DateTime(2026),
        trabajoId: 'demo-t1',
        esDemo: true,
      );
      final restaurada = Cita.fromJson(cita.toJson());
      expect(restaurada.esDemo, isTrue);
      expect(restaurada.trabajoId, 'demo-t1');
    });
  });
}
