// lib/core/theme/theme_controller.dart
//
// Preferencia de apariencia (modo oscuro), persistida en el mismo
// LocalStore que usan los repositorios. El constructor sin argumentos
// (en memoria, sin persistencia) existe para no obligar a cada pantalla
// y cada test a enhebrar una instancia real -- ver DashboardScreen.
import 'package:flutter/foundation.dart';

import '../../data/local/local_store.dart';
import 'app_colors.dart';

class ThemeController extends ChangeNotifier {
  ThemeController([this._store]);

  static const _key = 'oficio_ai.modo_oscuro';

  final LocalStore? _store;
  bool _oscuro = false;

  bool get oscuro => _oscuro;

  static Future<ThemeController> bootstrap() async {
    final controller = ThemeController(await LocalStore.open());
    await controller.cargar();
    return controller;
  }

  Future<void> cargar() async {
    final store = _store;
    if (store == null) return;
    _oscuro = store.readBool(_key, orElse: false);
    AppColors.actualizar(_oscuro ? AppAppearance.oscuro : AppAppearance.claro);
    notifyListeners();
  }

  Future<void> cambiar(bool oscuro) async {
    _oscuro = oscuro;
    AppColors.actualizar(oscuro ? AppAppearance.oscuro : AppAppearance.claro);
    notifyListeners();
    await _store?.writeBool(_key, oscuro);
  }
}
