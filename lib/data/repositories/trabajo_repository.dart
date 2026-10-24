// lib/data/repositories/trabajo_repository.dart
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/trabajo.dart';

class TrabajoRepository extends ChangeNotifier {
  TrabajoRepository(this._store);

  static const _key = 'oficio_ai.trabajos';

  final LocalStore _store;
  List<Trabajo> _trabajos = [];

  List<Trabajo> get trabajos => List.unmodifiable(_trabajos);

  List<Trabajo> porCliente(String clienteId) =>
      _trabajos.where((t) => t.clienteId == clienteId).toList();

  /// Trabajos creados a partir de un presupuesto concreto -- la relación
  /// presupuesto→trabajo se deriva de aquí (lado del trabajo), nunca se
  /// escribe en el presupuesto, para no tener que tocarlo al crear un
  /// trabajo desde él.
  List<Trabajo> porPresupuesto(String presupuestoId) =>
      _trabajos.where((t) => t.presupuestoId == presupuestoId).toList();

  Trabajo? byId(String id) {
    for (final t in _trabajos) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load() async {
    final raw = _store.readList(_key);
    _trabajos = raw.map(Trabajo.fromJson).toList()
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Trabajo> seed) async {
    if (_trabajos.isNotEmpty) return;
    _trabajos = [...seed]..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> add(Trabajo trabajo) async {
    _trabajos = [..._trabajos, trabajo]
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> update(Trabajo trabajo) async {
    _trabajos = _trabajos.map((t) => t.id == trabajo.id ? trabajo : t).toList()
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _trabajos = _trabajos.where((t) => t.id != id).toList();
    await _persist();
    notifyListeners();
  }

  /// Borra todos los trabajos del dispositivo -- usado al "cerrar
  /// sesión" (ver settings_screen.dart).
  Future<void> limpiar() async {
    _trabajos = [];
    await _store.remove(_key);
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _trabajos.map((t) => t.toJson()).toList());
}
