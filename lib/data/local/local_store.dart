// lib/data/local/local_store.dart
//
// Persistencia local del prototipo: cada colección se guarda como una
// lista JSON bajo una clave de SharedPreferences. Suficiente para una
// demo de un único usuario en un único dispositivo -- ver limitaciones en
// README.md (no es una base de datos real, no sincroniza, no escala a
// volúmenes grandes de datos).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) {
    return _prefs.setString(key, jsonEncode(value));
  }

  /// Para datos que son un único objeto, no una colección -- p. ej. la
  /// configuración del negocio (ver negocio_repository.dart). Mismo
  /// mecanismo que readList/writeList, sin montar una colección de un
  /// solo elemento para algo que nunca es una lista.
  Map<String, dynamic>? readObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> writeObject(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, jsonEncode(value));
  }
}
