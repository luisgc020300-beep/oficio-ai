// test/negocio_repository_test.dart
//
// NegocioRepository: configuración inicialmente vacía, guardar/cargar,
// persistencia tras reinicializar el repositorio, y que nunca se siembra
// con datos de ejemplo al reiniciar (encargo iteración 6, sección 10,
// puntos 1, 2 y 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/repositories/negocio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  test('configuración inicialmente vacía: datos es null, no lanza', () async {
    final repo = NegocioRepository(store);
    await repo.load();
    expect(repo.datos, isNull);
  });

  test('guardar() persiste y queda disponible de inmediato en datos', () async {
    final repo = NegocioRepository(store);
    await repo.load();
    await repo.guardar(
      const DatosNegocio(nombreFiscal: 'Juan Pérez García', nif: '12345678Z'),
    );
    expect(repo.datos?.nombreFiscal, 'Juan Pérez García');
  });

  test('los datos sobreviven a un repositorio nuevo sobre el mismo '
      'almacenamiento (simula cerrar y volver a abrir la app)', () async {
    final repo1 = NegocioRepository(store);
    await repo1.load();
    await repo1.guardar(
      const DatosNegocio(
        nombreFiscal: 'Juan Pérez García',
        nif: '12345678Z',
        direccion: 'Calle Mayor 1',
        codigoPostal: '28001',
        localidad: 'Madrid',
        provincia: 'Madrid',
      ),
    );

    final repo2 = NegocioRepository(store);
    await repo2.load();

    expect(repo2.datos, isNotNull);
    expect(repo2.datos!.nombreFiscal, 'Juan Pérez García');
    expect(repo2.datos!.listoParaFacturar, isTrue);
  });

  test('guardar() dos veces no crea dos perfiles -- el segundo '
      'reemplaza al primero, sigue siendo uno solo', () async {
    final repo = NegocioRepository(store);
    await repo.load();
    await repo.guardar(
      const DatosNegocio(nombreFiscal: 'Primero', nif: '12345678Z'),
    );
    await repo.guardar(
      const DatosNegocio(nombreFiscal: 'Segundo', nif: '12345678Z'),
    );

    final repo2 = NegocioRepository(store);
    await repo2.load();
    expect(repo2.datos!.nombreFiscal, 'Segundo');
  });

  test('un objeto guardado con un formato antiguo/incompleto (solo '
      'nombre y NIF) se lee sin lanzar', () async {
    await store.writeObject('oficio_ai.negocio', {
      'nombreFiscal': 'Juan Pérez',
      'nif': '12345678Z',
    });
    final repo = NegocioRepository(store);
    await repo.load();
    expect(repo.datos!.nombreFiscal, 'Juan Pérez');
    expect(repo.datos!.direccion, isNull);
    expect(repo.datos!.listoParaFacturar, isFalse);
  });

  test('notifica a los listeners al guardar, para que la interfaz '
      'refleje el cambio', () async {
    final repo = NegocioRepository(store);
    await repo.load();
    var notificado = false;
    repo.addListener(() => notificado = true);
    await repo.guardar(
      const DatosNegocio(nombreFiscal: 'Juan Pérez', nif: '12345678Z'),
    );
    expect(notificado, isTrue);
  });
}
