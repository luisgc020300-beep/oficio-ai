// lib/data/repositories/negocio_repository.dart
//
// A diferencia de los demás repositorios, no gestiona una colección:
// hay un único negocio (el del propio usuario), así que no hay add/
// delete/byId -- solo cargar y guardar un objeto que puede no existir
// todavía (antes de la primera vez que el usuario rellena "Mi
// negocio").
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/datos_negocio.dart';

class NegocioRepository extends ChangeNotifier {
  NegocioRepository(this._store);

  static const _key = 'oficio_ai.negocio';

  final LocalStore _store;
  DatosNegocio? _datos;

  /// null mientras el usuario no haya guardado nunca sus datos.
  DatosNegocio? get datos => _datos;

  Future<void> load() async {
    final raw = _store.readObject(_key);
    _datos = raw == null ? null : DatosNegocio.fromJson(raw);
    notifyListeners();
  }

  Future<void> guardar(DatosNegocio datos) async {
    _datos = datos;
    await _store.writeObject(_key, datos.toJson());
    notifyListeners();
  }

  /// Borra los datos del negocio del dispositivo -- usado al "cerrar
  /// sesión" (ver settings_screen.dart).
  Future<void> limpiar() async {
    _datos = null;
    await _store.remove(_key);
    notifyListeners();
  }
}
