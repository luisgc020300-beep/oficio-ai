// lib/data/repositories/nota_seguimiento_repository.dart
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/nota_seguimiento.dart';

class NotaSeguimientoRepository extends ChangeNotifier {
  NotaSeguimientoRepository(this._store);

  static const _key = 'oficio_ai.notas_seguimiento';

  final LocalStore _store;
  List<NotaSeguimiento> _notas = [];

  List<NotaSeguimiento> get notas => List.unmodifiable(_notas);

  NotaSeguimiento? byId(String id) {
    for (final n in _notas) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Notas de un cliente, más recientes primero -- mismo criterio de
  /// orden que trabajos/presupuestos/facturas.
  List<NotaSeguimiento> porCliente(String clienteId) =>
      _notas.where((n) => n.clienteId == clienteId).toList()
        ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));

  Future<void> load() async {
    final raw = _store.readList(_key);
    _notas = raw.map(NotaSeguimiento.fromJson).toList()
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    notifyListeners();
  }

  void _validar(NotaSeguimiento nota) {
    if (nota.texto.trim().isEmpty) {
      throw ArgumentError('El texto de la nota es obligatorio.');
    }
    if (nota.fechaSeguimiento != null && nota.estadoSeguimiento == null) {
      throw ArgumentError('Una nota con seguimiento necesita un estado.');
    }
  }

  Future<void> add(NotaSeguimiento nota) async {
    // Al programar un seguimiento sin indicar estado, empieza pendiente
    // -- evita que cada pantalla tenga que acordarse de fijarlo.
    final aGuardar = nota.fechaSeguimiento != null && nota.estadoSeguimiento == null
        ? nota.copyWith(estadoSeguimiento: EstadoSeguimiento.pendiente)
        : nota;
    _validar(aGuardar);
    await _guardar([..._notas, aGuardar]);
  }

  Future<void> actualizar(NotaSeguimiento nota) async {
    final actual = byId(nota.id);
    if (actual == null) {
      throw StateError('Esta nota ya no existe.');
    }
    final aGuardar = nota.fechaSeguimiento != null && nota.estadoSeguimiento == null
        ? nota.copyWith(estadoSeguimiento: EstadoSeguimiento.pendiente)
        : nota;
    _validar(aGuardar);
    await _guardar(_notas.map((n) => n.id == nota.id ? aGuardar : n).toList());
  }

  /// No es un registro económico -- a diferencia de Factura/Gasto, una
  /// nota se puede borrar de verdad, sin dejar rastro "anulado" (no hay
  /// nada fiscal que proteger aquí).
  Future<void> eliminar(String id) async {
    await _guardar(_notas.where((n) => n.id != id).toList());
  }

  Future<void> marcarSeguimientoRealizado(String id) => _cambiarEstadoSeguimiento(
    id,
    EstadoSeguimiento.realizado,
  );

  Future<void> marcarSeguimientoCancelado(String id) => _cambiarEstadoSeguimiento(
    id,
    EstadoSeguimiento.cancelado,
  );

  Future<void> _cambiarEstadoSeguimiento(String id, EstadoSeguimiento estado) async {
    final actual = byId(id);
    if (actual == null) {
      throw StateError('Esta nota ya no existe.');
    }
    if (!actual.tieneSeguimiento) {
      throw StateError('Esta nota no tiene ningún seguimiento programado.');
    }
    await _guardar(
      _notas.map((n) => n.id == id ? n.copyWith(estadoSeguimiento: estado) : n).toList(),
    );
  }

  /// Borra todas las notas del dispositivo -- usado al "cerrar sesión"
  /// (ver settings_screen.dart).
  Future<void> limpiar() async {
    _notas = [];
    await _store.remove(_key);
    notifyListeners();
  }

  Future<void> _guardar(List<NotaSeguimiento> nuevaLista) async {
    final anterior = _notas;
    _notas = nuevaLista..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    try {
      await _persist();
    } catch (_) {
      _notas = anterior;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _notas.map((n) => n.toJson()).toList());
}
