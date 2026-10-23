// test/cliente_repository_test.dart
//
// CRUD del repositorio de clientes contra SharedPreferences simulado --
// confirma que add/update/delete persisten y que un repositorio nuevo
// leyendo el mismo almacenamiento recupera los mismos datos.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/repositories/cliente_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  test('empieza vacío si no hay nada guardado', () async {
    final repo = ClienteRepository(store);
    await repo.load();
    expect(repo.clientes, isEmpty);
  });

  test('add() guarda un cliente y lo mantiene ordenado por nombre', () async {
    final repo = ClienteRepository(store);
    await repo.load();
    await repo.add(
      Cliente(id: '1', nombre: 'Zacarías', creadoEl: DateTime(2026)),
    );
    await repo.add(
      Cliente(id: '2', nombre: 'Ana', creadoEl: DateTime(2026)),
    );

    expect(repo.clientes.map((c) => c.nombre), ['Ana', 'Zacarías']);
  });

  test('update() solo cambia el cliente indicado', () async {
    final repo = ClienteRepository(store);
    await repo.load();
    await repo.add(
      Cliente(id: '1', nombre: 'Marta', creadoEl: DateTime(2026)),
    );

    await repo.update(
      repo.byId('1')!.copyWith(telefono: '600 000 000'),
    );

    expect(repo.byId('1')!.telefono, '600 000 000');
    expect(repo.byId('1')!.nombre, 'Marta');
  });

  test('delete() quita el cliente de la lista', () async {
    final repo = ClienteRepository(store);
    await repo.load();
    await repo.add(
      Cliente(id: '1', nombre: 'Marta', creadoEl: DateTime(2026)),
    );
    await repo.delete('1');

    expect(repo.clientes, isEmpty);
  });

  test('los cambios persisten y los lee un repositorio nuevo', () async {
    final repo1 = ClienteRepository(store);
    await repo1.load();
    await repo1.add(
      Cliente(id: '1', nombre: 'Marta', creadoEl: DateTime(2026)),
    );

    final repo2 = ClienteRepository(store);
    await repo2.load();

    expect(repo2.clientes, hasLength(1));
    expect(repo2.clientes.first.nombre, 'Marta');
  });

  test('seedIfEmpty() no sobrescribe datos ya existentes', () async {
    final repo = ClienteRepository(store);
    await repo.load();
    await repo.add(
      Cliente(id: '1', nombre: 'Marta', creadoEl: DateTime(2026)),
    );

    await repo.seedIfEmpty([
      Cliente(id: 'demo', nombre: 'Demo', creadoEl: DateTime(2026)),
    ]);

    expect(repo.clientes, hasLength(1));
    expect(repo.clientes.first.nombre, 'Marta');
  });
}
