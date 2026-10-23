// lib/data/repositories/presupuesto_repository.dart
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/presupuesto.dart';

class PresupuestoRepository extends ChangeNotifier {
  PresupuestoRepository(this._store);

  static const _key = 'oficio_ai.presupuestos';

  final LocalStore _store;
  List<Presupuesto> _presupuestos = [];

  List<Presupuesto> get presupuestos => List.unmodifiable(_presupuestos);

  List<Presupuesto> porCliente(String clienteId) =>
      _presupuestos.where((p) => p.clienteId == clienteId).toList();

  Presupuesto? byId(String id) {
    for (final p in _presupuestos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    final raw = _store.readList(_key);
    _presupuestos = raw.map(Presupuesto.fromJson).toList()
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Presupuesto> seed) async {
    if (_presupuestos.isNotEmpty) return;
    _presupuestos = [...seed]
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> add(Presupuesto presupuesto) async {
    _presupuestos = [..._presupuestos, presupuesto]
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> update(Presupuesto presupuesto) async {
    _presupuestos =
        _presupuestos
            .map((p) => p.id == presupuesto.id ? presupuesto : p)
            .toList()
          ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _presupuestos = _presupuestos.where((p) => p.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _presupuestos.map((p) => p.toJson()).toList());
}
