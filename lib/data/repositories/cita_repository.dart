// lib/data/repositories/cita_repository.dart
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/cita.dart';

class CitaRepository extends ChangeNotifier {
  CitaRepository(this._store);

  static const _key = 'oficio_ai.citas';

  final LocalStore _store;
  List<Cita> _citas = [];

  List<Cita> get citas => List.unmodifiable(_citas);

  /// Citas programadas para un trabajo concreto.
  List<Cita> porTrabajo(String trabajoId) =>
      _citas.where((c) => c.trabajoId == trabajoId).toList();

  /// Citas de un cliente concreto, ordenadas por fecha (ascendente,
  /// igual que [citas]) -- quien busque "la próxima" filtra sobre el
  /// resultado (ver client_detail_screen.dart).
  List<Cita> porCliente(String clienteId) =>
      _citas.where((c) => c.clienteId == clienteId).toList();

  List<Cita> delDia(DateTime dia) => _citas
      .where(
        (c) =>
            c.fechaHora.year == dia.year &&
            c.fechaHora.month == dia.month &&
            c.fechaHora.day == dia.day,
      )
      .toList();

  Future<void> load() async {
    final raw = _store.readList(_key);
    _citas = raw.map(Cita.fromJson).toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Cita> seed) async {
    if (_citas.isNotEmpty) return;
    _citas = [...seed]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    await _persist();
    notifyListeners();
  }

  Future<void> add(Cita cita) async {
    _citas = [..._citas, cita]
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    await _persist();
    notifyListeners();
  }

  Future<void> update(Cita cita) async {
    _citas = _citas.map((c) => c.id == cita.id ? cita : c).toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _citas = _citas.where((c) => c.id != id).toList();
    await _persist();
    notifyListeners();
  }

  /// Borra todas las citas del dispositivo -- usado al "cerrar sesión"
  /// (ver settings_screen.dart).
  Future<void> limpiar() async {
    _citas = [];
    await _store.remove(_key);
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _citas.map((c) => c.toJson()).toList());
}
