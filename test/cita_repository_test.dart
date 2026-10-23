// test/cita_repository_test.dart
//
// CRUD del repositorio de citas -- no tenía test hasta esta iteración,
// en la que además se añadió la opción de eliminar una cita desde la UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/repositories/cita_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  test('empieza vacío si no hay nada guardado', () async {
    final repo = CitaRepository(store);
    await repo.load();
    expect(repo.citas, isEmpty);
  });

  test('add() guarda la cita ordenada por fecha/hora', () async {
    final repo = CitaRepository(store);
    await repo.load();
    await repo.add(
      Cita(id: '1', titulo: 'Tarde', fechaHora: DateTime(2026, 1, 1, 17)),
    );
    await repo.add(
      Cita(id: '2', titulo: 'Mañana', fechaHora: DateTime(2026, 1, 1, 9)),
    );

    expect(repo.citas.map((c) => c.titulo), ['Mañana', 'Tarde']);
  });

  test('delDia() solo devuelve las citas de ese día concreto', () async {
    final repo = CitaRepository(store);
    await repo.load();
    await repo.add(
      Cita(id: '1', titulo: 'Hoy', fechaHora: DateTime(2026, 1, 1, 9)),
    );
    await repo.add(
      Cita(id: '2', titulo: 'Mañana', fechaHora: DateTime(2026, 1, 2, 9)),
    );

    final deEse1Enero = repo.delDia(DateTime(2026, 1, 1));
    expect(deEse1Enero, hasLength(1));
    expect(deEse1Enero.first.titulo, 'Hoy');
  });

  test('update() cambia completada sin tocar el resto de campos', () async {
    final repo = CitaRepository(store);
    await repo.load();
    await repo.add(
      Cita(id: '1', titulo: 'Visita', fechaHora: DateTime(2026, 1, 1, 9)),
    );

    final cita = repo.citas.first;
    await repo.update(cita.copyWith(completada: true));

    expect(repo.citas.first.completada, isTrue);
    expect(repo.citas.first.titulo, 'Visita');
  });

  test('delete() quita la cita de la lista', () async {
    final repo = CitaRepository(store);
    await repo.load();
    await repo.add(
      Cita(id: '1', titulo: 'Visita', fechaHora: DateTime(2026, 1, 1, 9)),
    );
    await repo.delete('1');

    expect(repo.citas, isEmpty);
  });

  test('los cambios persisten entre instancias del repositorio', () async {
    final repo1 = CitaRepository(store);
    await repo1.load();
    await repo1.add(
      Cita(id: '1', titulo: 'Visita', fechaHora: DateTime(2026, 1, 1, 9)),
    );

    final repo2 = CitaRepository(store);
    await repo2.load();

    expect(repo2.citas, hasLength(1));
    expect(repo2.citas.first.titulo, 'Visita');
  });
}
