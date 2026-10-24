// test/gasto_repository_test.dart
//
// Reglas de GastoRepository: validación de descripción/importe,
// trazabilidad (no se edita ni se borra un gasto anulado), filtros por
// trabajo y persistencia -- mismo patrón que factura_repository_test.dart
// (encargo iteración 9, secciones 1, 2 y 7).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/gasto.dart';
import 'package:oficio_ai/data/repositories/gasto_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Gasto _gasto({
  String id = 'g1',
  String descripcion = 'Material',
  double importe = 50,
  DateTime? fecha,
  CategoriaGasto categoria = CategoriaGasto.materiales,
  String? trabajoId,
}) => Gasto(
  id: id,
  descripcion: descripcion,
  importe: importe,
  fecha: fecha ?? DateTime(2026, 3, 1),
  categoria: categoria,
  trabajoId: trabajoId,
  creadoEl: DateTime(2026, 3, 1),
);

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  group('add()', () {
    test('guarda un gasto válido', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      expect(repo.gastos, hasLength(1));
      expect(repo.byId('g1')!.estado, EstadoGasto.activo);
    });

    test('rechaza una descripción vacía', () async {
      final repo = GastoRepository(store);
      await repo.load();
      expect(
        () => repo.add(_gasto(descripcion: '   ')),
        throwsArgumentError,
      );
    });

    test('rechaza un importe cero o negativo', () async {
      final repo = GastoRepository(store);
      await repo.load();
      expect(() => repo.add(_gasto(importe: 0)), throwsArgumentError);
      expect(() => repo.add(_gasto(importe: -10)), throwsArgumentError);
    });

    test('rechaza crear directamente un gasto ya anulado', () async {
      final repo = GastoRepository(store);
      await repo.load();
      final anulado = Gasto(
        id: 'g1',
        descripcion: 'x',
        importe: 10,
        fecha: DateTime(2026, 1, 1),
        creadoEl: DateTime(2026, 1, 1),
        estado: EstadoGasto.anulado,
        motivoAnulacion: 'x',
        fechaAnulacion: DateTime(2026, 1, 1),
      );
      expect(() => repo.add(anulado), throwsStateError);
    });
  });

  group('update()', () {
    test('edita un gasto activo', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      await repo.update(repo.byId('g1')!.copyWith(descripcion: 'Material corregido'));
      expect(repo.byId('g1')!.descripcion, 'Material corregido');
    });

    test('rechaza editar un gasto ya anulado', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      await repo.anular('g1', 'Error al registrarlo');
      expect(
        () => repo.update(repo.byId('g1')!.copyWith(descripcion: 'Intento de editar')),
        throwsStateError,
      );
    });

    test('rechaza un importe inválido también al editar', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      expect(
        () => repo.update(repo.byId('g1')!.copyWith(importe: -5)),
        throwsArgumentError,
      );
    });
  });

  group('anular()', () {
    test('exige un motivo', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      expect(() => repo.anular('g1', ''), throwsArgumentError);
      expect(() => repo.anular('g1', '   '), throwsArgumentError);
    });

    test('preserva el importe, la fecha y el trabajo asociado -- solo '
        'cambia el estado', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto(trabajoId: 't1', importe: 75));
      final anulado = await repo.anular('g1', 'Duplicado por error');
      expect(anulado.estado, EstadoGasto.anulado);
      expect(anulado.importe, 75);
      expect(anulado.trabajoId, 't1');
      expect(anulado.motivoAnulacion, 'Duplicado por error');
      expect(anulado.fechaAnulacion, isNotNull);
    });

    test('un gasto anulado nunca cuenta en activos', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto(id: 'g1', importe: 30));
      await repo.add(_gasto(id: 'g2', importe: 20));
      await repo.anular('g1', 'Motivo');
      expect(repo.activos.map((g) => g.id), ['g2']);
      expect(repo.activos.fold<double>(0, (acc, g) => acc + g.importe), 20);
    });

    test('rechaza anular dos veces', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto());
      await repo.anular('g1', 'Motivo');
      expect(() => repo.anular('g1', 'Otro motivo'), throwsStateError);
    });

    test('rechaza anular un gasto inexistente', () async {
      final repo = GastoRepository(store);
      await repo.load();
      expect(() => repo.anular('no-existe', 'Motivo'), throwsStateError);
    });
  });

  group('porTrabajo() y filtros', () {
    test('encuentra solo los gastos del trabajo indicado, vigentes o '
        'anulados', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto(id: 'g1', trabajoId: 't1'));
      await repo.add(_gasto(id: 'g2', trabajoId: 't2'));
      await repo.add(_gasto(id: 'g3', trabajoId: 't1'));
      await repo.anular('g3', 'Motivo');

      final deT1 = repo.porTrabajo('t1');
      expect(deT1.map((g) => g.id), containsAll(['g1', 'g3']));
      expect(repo.porTrabajo('t2').map((g) => g.id), ['g2']);
    });

    test('un gasto sin trabajo asociado no aparece en porTrabajo() de '
        'ningún trabajo, pero sigue en gastos/activos', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto(id: 'g1', trabajoId: null));
      expect(repo.porTrabajo('t1'), isEmpty);
      expect(repo.gastos.map((g) => g.id), ['g1']);
      expect(repo.activos.map((g) => g.id), ['g1']);
    });
  });

  group('persistencia', () {
    test('los gastos, su estado y su relación con el trabajo '
        'sobreviven a un repositorio nuevo sobre el mismo '
        'almacenamiento', () async {
      final repo1 = GastoRepository(store);
      await repo1.load();
      await repo1.add(_gasto(id: 'g1', trabajoId: 't1', importe: 60));
      await repo1.add(_gasto(id: 'g2'));
      await repo1.anular('g2', 'Registrado por error');

      final repo2 = GastoRepository(store);
      await repo2.load();
      expect(repo2.byId('g1')!.trabajoId, 't1');
      expect(repo2.byId('g1')!.importe, 60);
      expect(repo2.byId('g2')!.estado, EstadoGasto.anulado);
      expect(repo2.byId('g2')!.motivoAnulacion, 'Registrado por error');
    });

    test('seedIfEmpty() no sobrescribe gastos ya existentes', () async {
      final repo = GastoRepository(store);
      await repo.load();
      await repo.add(_gasto(id: 'real'));
      await repo.seedIfEmpty([_gasto(id: 'demo')]);
      expect(repo.gastos, hasLength(1));
      expect(repo.gastos.first.id, 'real');
    });
  });
}
