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
import 'repositories/factura_repository.dart';
import 'repositories/gasto_repository.dart';
import 'repositories/negocio_repository.dart';
import 'repositories/nota_seguimiento_repository.dart';
import 'repositories/presupuesto_repository.dart';
import 'repositories/trabajo_repository.dart';

class AppData {
  AppData(LocalStore store)
    : clientes = ClienteRepository(store),
      trabajos = TrabajoRepository(store),
      presupuestos = PresupuestoRepository(store),
      citas = CitaRepository(store),
      facturas = FacturaRepository(store),
      gastos = GastoRepository(store),
      negocio = NegocioRepository(store),
      notasSeguimiento = NotaSeguimientoRepository(store);

  final ClienteRepository clientes;
  final TrabajoRepository trabajos;
  final PresupuestoRepository presupuestos;
  final CitaRepository citas;
  final FacturaRepository facturas;
  final GastoRepository gastos;
  final NegocioRepository negocio;
  final NotaSeguimientoRepository notasSeguimiento;

  static Future<AppData> bootstrap() async {
    final store = await LocalStore.open();
    final data = AppData(store);
    await Future.wait([
      data.clientes.load(),
      data.trabajos.load(),
      data.presupuestos.load(),
      data.citas.load(),
      data.facturas.load(),
      data.gastos.load(),
      data.negocio.load(),
      data.notasSeguimiento.load(),
    ]);
    // Solo siembra datos de ejemplo si el usuario nunca ha guardado nada
    // propio todavía -- ver demo_seed.dart. Los gastos no tienen semilla
    // de ejemplo en esta iteración (sección 6: no meter datos demo en
    // los totales reales sin señalarlos -- más simple no añadir ninguno
    // todavía que tener que etiquetarlos bien desde el primer día).
    await data.clientes.seedIfEmpty(demoClientes);
    await data.trabajos.seedIfEmpty(demoTrabajos);
    await data.presupuestos.seedIfEmpty(demoPresupuestos);
    await data.citas.seedIfEmpty(demoCitas);
    await data.facturas.seedIfEmpty(demoFacturas);
    return data;
  }

  /// "Cerrar sesión" (pantalla de Ajustes): esta app no tiene cuentas ni
  /// backend -- todo vive en este dispositivo -- así que lo más honesto
  /// que puede hacer un "cerrar sesión" es borrar esos datos y dejar la
  /// app como recién instalada, con la misma semilla de ejemplo que
  /// vería alguien que la abre por primera vez (ver bootstrap()).
  Future<void> cerrarSesion() async {
    await Future.wait([
      clientes.limpiar(),
      trabajos.limpiar(),
      presupuestos.limpiar(),
      citas.limpiar(),
      facturas.limpiar(),
      gastos.limpiar(),
      negocio.limpiar(),
      notasSeguimiento.limpiar(),
    ]);
    await clientes.seedIfEmpty(demoClientes);
    await trabajos.seedIfEmpty(demoTrabajos);
    await presupuestos.seedIfEmpty(demoPresupuestos);
    await citas.seedIfEmpty(demoCitas);
    await facturas.seedIfEmpty(demoFacturas);
  }
}
