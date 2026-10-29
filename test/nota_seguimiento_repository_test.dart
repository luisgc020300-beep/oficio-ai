// test/nota_seguimiento_repository_test.dart
//
// Repositorio de notas de seguimiento (iteración 11): crear/recuperar,
// validación de texto vacío, orden cronológico, persistencia tras
// reiniciar el repositorio, y el ciclo de vida de un seguimiento
// (programar, marcar realizado/cancelado, y la clasificación hoy/
// futuro/atrasado, que nunca cambia sola con el paso del tiempo).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/nota_seguimiento.dart';
import 'package:oficio_ai/data/repositories/nota_seguimiento_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  test('empieza vacío si no hay nada guardado', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();
    expect(repo.notas, isEmpty);
  });

  test('add() guarda la nota y la deja consultable por cliente', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();
    await repo.add(
      NotaSeguimiento(
        id: 'n1',
        clienteId: 'c1',
        texto: 'Llamó preguntando por el presupuesto',
        tipo: TipoNota.llamada,
        creadoEl: DateTime(2026, 1, 1),
      ),
    );

    expect(repo.notas, hasLength(1));
    expect(repo.porCliente('c1'), hasLength(1));
    expect(repo.porCliente('c2'), isEmpty);
    expect(repo.byId('n1')!.tipo, TipoNota.llamada);
  });

  test('add() rechaza un texto vacío y no guarda nada', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();

    expect(
      () => repo.add(
        NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: '   ', creadoEl: DateTime(2026)),
      ),
      throwsArgumentError,
    );
    expect(repo.notas, isEmpty);
  });

  test('porCliente() ordena cronológicamente, más reciente primero', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();
    await repo.add(
      NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Primera', creadoEl: DateTime(2026, 1, 1)),
    );
    await repo.add(
      NotaSeguimiento(id: 'n2', clienteId: 'c1', texto: 'Tercera', creadoEl: DateTime(2026, 1, 10)),
    );
    await repo.add(
      NotaSeguimiento(id: 'n3', clienteId: 'c1', texto: 'Segunda', creadoEl: DateTime(2026, 1, 5)),
    );

    expect(repo.porCliente('c1').map((n) => n.texto), ['Tercera', 'Segunda', 'Primera']);
  });

  test('los cambios persisten y los lee un repositorio nuevo', () async {
    final repo1 = NotaSeguimientoRepository(store);
    await repo1.load();
    await repo1.add(
      NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Nota de prueba', creadoEl: DateTime(2026)),
    );

    final repo2 = NotaSeguimientoRepository(store);
    await repo2.load();

    expect(repo2.notas, hasLength(1));
    expect(repo2.notas.first.texto, 'Nota de prueba');
  });

  test('actualizar() edita el texto sin tocar el resto', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();
    await repo.add(
      NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Texto original', creadoEl: DateTime(2026)),
    );

    await repo.actualizar(repo.byId('n1')!.copyWith(texto: 'Texto corregido'));

    expect(repo.byId('n1')!.texto, 'Texto corregido');
    expect(repo.byId('n1')!.clienteId, 'c1');
  });

  test('eliminar() borra la nota de verdad -- no es un registro económico', () async {
    final repo = NotaSeguimientoRepository(store);
    await repo.load();
    await repo.add(
      NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Para borrar', creadoEl: DateTime(2026)),
    );

    await repo.eliminar('n1');

    expect(repo.notas, isEmpty);
  });

  group('seguimiento', () {
    test('al programar un seguimiento sin estado, empieza pendiente', () async {
      final repo = NotaSeguimientoRepository(store);
      await repo.load();
      await repo.add(
        NotaSeguimiento(
          id: 'n1',
          clienteId: 'c1',
          texto: 'Volver a llamar',
          creadoEl: DateTime(2026, 1, 1),
          fechaSeguimiento: DateTime(2026, 2, 1),
        ),
      );

      expect(repo.byId('n1')!.estadoSeguimiento, EstadoSeguimiento.pendiente);
    });

    test('marcarSeguimientoRealizado() cambia el estado sin tocar la fecha', () async {
      final repo = NotaSeguimientoRepository(store);
      await repo.load();
      await repo.add(
        NotaSeguimiento(
          id: 'n1',
          clienteId: 'c1',
          texto: 'Volver a llamar',
          creadoEl: DateTime(2026, 1, 1),
          fechaSeguimiento: DateTime(2026, 2, 1),
        ),
      );

      await repo.marcarSeguimientoRealizado('n1');

      expect(repo.byId('n1')!.estadoSeguimiento, EstadoSeguimiento.realizado);
      expect(repo.byId('n1')!.fechaSeguimiento, DateTime(2026, 2, 1));
    });

    test('marcarSeguimientoCancelado() cambia el estado', () async {
      final repo = NotaSeguimientoRepository(store);
      await repo.load();
      await repo.add(
        NotaSeguimiento(
          id: 'n1',
          clienteId: 'c1',
          texto: 'Volver a llamar',
          creadoEl: DateTime(2026, 1, 1),
          fechaSeguimiento: DateTime(2026, 2, 1),
        ),
      );

      await repo.marcarSeguimientoCancelado('n1');

      expect(repo.byId('n1')!.estadoSeguimiento, EstadoSeguimiento.cancelado);
    });

    test('marcar un seguimiento falla sobre una nota sin seguimiento programado', () async {
      final repo = NotaSeguimientoRepository(store);
      await repo.load();
      await repo.add(
        NotaSeguimiento(id: 'n1', clienteId: 'c1', texto: 'Solo una nota', creadoEl: DateTime(2026)),
      );

      expect(() => repo.marcarSeguimientoRealizado('n1'), throwsStateError);
    });

    test('hoy / futuro / atrasado se calculan contra "ahora", nunca contra la fecha real', () {
      final ahora = DateTime(2026, 6, 15, 10);

      final atrasada = NotaSeguimiento(
        id: 'a',
        clienteId: 'c1',
        texto: 'x',
        creadoEl: ahora,
        fechaSeguimiento: DateTime(2026, 6, 10),
        estadoSeguimiento: EstadoSeguimiento.pendiente,
      );
      final deHoy = NotaSeguimiento(
        id: 'h',
        clienteId: 'c1',
        texto: 'x',
        creadoEl: ahora,
        fechaSeguimiento: DateTime(2026, 6, 15, 18),
        estadoSeguimiento: EstadoSeguimiento.pendiente,
      );
      final futura = NotaSeguimiento(
        id: 'f',
        clienteId: 'c1',
        texto: 'x',
        creadoEl: ahora,
        fechaSeguimiento: DateTime(2026, 6, 20),
        estadoSeguimiento: EstadoSeguimiento.pendiente,
      );

      expect(atrasada.esSeguimientoAtrasado(ahora: ahora), isTrue);
      expect(atrasada.esSeguimientoHoy(ahora: ahora), isFalse);
      expect(atrasada.esSeguimientoFuturo(ahora: ahora), isFalse);

      expect(deHoy.esSeguimientoHoy(ahora: ahora), isTrue);
      expect(deHoy.esSeguimientoAtrasado(ahora: ahora), isFalse);
      expect(deHoy.esSeguimientoFuturo(ahora: ahora), isFalse);

      expect(futura.esSeguimientoFuturo(ahora: ahora), isTrue);
      expect(futura.esSeguimientoAtrasado(ahora: ahora), isFalse);
      expect(futura.esSeguimientoHoy(ahora: ahora), isFalse);
    });

    test('un seguimiento ya realizado no se clasifica como atrasado aunque su fecha ya pasó', () {
      final ahora = DateTime(2026, 6, 15);
      final nota = NotaSeguimiento(
        id: 'r',
        clienteId: 'c1',
        texto: 'x',
        creadoEl: ahora,
        fechaSeguimiento: DateTime(2026, 1, 1),
        estadoSeguimiento: EstadoSeguimiento.realizado,
      );

      expect(nota.esSeguimientoAtrasado(ahora: ahora), isFalse);
      expect(nota.esSeguimientoHoy(ahora: ahora), isFalse);
      expect(nota.esSeguimientoFuturo(ahora: ahora), isFalse);
    });

    test('una nota sin seguimiento nunca se clasifica en ningún grupo', () {
      final nota = NotaSeguimiento(id: 'n', clienteId: 'c1', texto: 'x', creadoEl: DateTime(2026));

      expect(nota.tieneSeguimiento, isFalse);
      expect(nota.esSeguimientoAtrasado(), isFalse);
      expect(nota.esSeguimientoHoy(), isFalse);
      expect(nota.esSeguimientoFuturo(), isFalse);
    });
  });
}
