// lib/data/repositories/cliente_repository.dart
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/cliente.dart';

class ClienteRepository extends ChangeNotifier {
  ClienteRepository(this._store);

  static const _key = 'oficio_ai.clientes';

  final LocalStore _store;
  List<Cliente> _clientes = [];

  List<Cliente> get clientes => List.unmodifiable(_clientes);

  Cliente? byId(String id) {
    for (final c in _clientes) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    final raw = _store.readList(_key);
    _clientes = raw.map(Cliente.fromJson).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Cliente> seed) async {
    if (_clientes.isNotEmpty) return;
    _clientes = [...seed]..sort((a, b) => a.nombre.compareTo(b.nombre));
    await _persist();
    notifyListeners();
  }

  Future<void> add(Cliente cliente) async {
    _clientes = [..._clientes, cliente]
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    await _persist();
    notifyListeners();
  }

  Future<void> update(Cliente cliente) async {
    _clientes = _clientes.map((c) => c.id == cliente.id ? cliente : c).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _clientes = _clientes.where((c) => c.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _clientes.map((c) => c.toJson()).toList());
}
