// lib/data/app_data.dart
//
// Punto único de acceso a los 4 repositorios -- se instancia una sola vez
// en main() y se pasa hacia abajo por el árbol de widgets (sin paquete de
// inyección de dependencias: con 4 repositorios, un constructor explícito
// es más simple de seguir que montar un service locator para esto).
import 'local/demo_seed.dart';
import 'local/local_store.dart';
import 'repositories/cita_repository.dart';
import 'repositories/cliente_repository.dart';
import 'repositories/presupuesto_repository.dart';
import 'repositories/trabajo_repository.dart';

class AppData {
  AppData(LocalStore store)
    : clientes = ClienteRepository(store),
      trabajos = TrabajoRepository(store),
      presupuestos = PresupuestoRepository(store),
      citas = CitaRepository(store);

  final ClienteRepository clientes;
  final TrabajoRepository trabajos;
  final PresupuestoRepository presupuestos;
  final CitaRepository citas;

  static Future<AppData> bootstrap() async {
    final store = await LocalStore.open();
    final data = AppData(store);
    await Future.wait([
      data.clientes.load(),
      data.trabajos.load(),
      data.presupuestos.load(),
      data.citas.load(),
    ]);
    // Solo siembra datos de ejemplo si el usuario nunca ha guardado nada
    // propio todavía -- ver demo_seed.dart.
    await data.clientes.seedIfEmpty(demoClientes);
    await data.trabajos.seedIfEmpty(demoTrabajos);
    await data.presupuestos.seedIfEmpty(demoPresupuestos);
    await data.citas.seedIfEmpty(demoCitas);
    return data;
  }
}
