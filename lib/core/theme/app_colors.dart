// lib/core/theme/app_colors.dart
//
// Paleta de Oficio AI: azul pizarra (confianza, profesional) + ámbar
// (oficio, trabajo manual, calidez) como único acento de llamada a la
// acción. Sin degradados, sin colores decorativos sueltos por pantalla.
//
// Modo oscuro (iteración de ajustes): en vez de enhebrar Theme.of(context)
// por las ~30 pantallas que ya usan `AppColors.xxx` como valor estático,
// estos campos pasan a ser getters que leen un modo mutable en memoria
// (ver ThemeController, que es el único que llama a actualizar()). Todo
// el árbol se reconstruye desde la raíz al cambiar de modo (ver
// main.dart), así que cada getter se vuelve a evaluar con el valor
// correcto sin tocar ninguna pantalla.
import 'package:flutter/material.dart';

enum AppAppearance { claro, oscuro }

class AppColors {
  AppColors._();

  static AppAppearance _modo = AppAppearance.claro;

  static bool get esOscuro => _modo == AppAppearance.oscuro;

  static void actualizar(AppAppearance modo) => _modo = modo;

  static Color get background => esOscuro ? _Dark.background : _Light.background;
  static Color get surface => esOscuro ? _Dark.surface : _Light.surface;
  static Color get surfaceMuted => esOscuro ? _Dark.surfaceMuted : _Light.surfaceMuted;
  static Color get border => esOscuro ? _Dark.border : _Light.border;

  static Color get ink => esOscuro ? _Dark.ink : _Light.ink;
  static Color get inkMuted => esOscuro ? _Dark.inkMuted : _Light.inkMuted;
  static Color get inkFaint => esOscuro ? _Dark.inkFaint : _Light.inkFaint;

  static Color get primary => esOscuro ? _Dark.primary : _Light.primary;
  static Color get primaryStrong => esOscuro ? _Dark.primaryStrong : _Light.primaryStrong;
  static Color get primaryTint => esOscuro ? _Dark.primaryTint : _Light.primaryTint;

  static Color get accent => esOscuro ? _Dark.accent : _Light.accent;
  static Color get accentStrong => esOscuro ? _Dark.accentStrong : _Light.accentStrong;
  static Color get accentTint => esOscuro ? _Dark.accentTint : _Light.accentTint;

  static Color get success => esOscuro ? _Dark.success : _Light.success;
  static Color get successTint => esOscuro ? _Dark.successTint : _Light.successTint;
  static Color get warning => esOscuro ? _Dark.warning : _Light.warning;
  static Color get warningTint => esOscuro ? _Dark.warningTint : _Light.warningTint;
  static Color get error => esOscuro ? _Dark.error : _Light.error;
  static Color get errorTint => esOscuro ? _Dark.errorTint : _Light.errorTint;
}

class _Light {
  _Light._();

  static const background = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFF1F4);
  static const border = Color(0xFFE2E5EA);

  static const ink = Color(0xFF16233B);
  static const inkMuted = Color(0xFF5B6475);
  static const inkFaint = Color(0xFF9AA2B1);

  static const primary = Color(0xFF1E3A5F);
  static const primaryStrong = Color(0xFF122840);
  static const primaryTint = Color(0x141E3A5F);

  static const accent = Color(0xFFE8912B);
  static const accentStrong = Color(0xFFC77418);
  static const accentTint = Color(0x1FE8912B);

  static const success = Color(0xFF1F8A5B);
  static const successTint = Color(0x1A1F8A5B);
  static const warning = Color(0xFFD9A441);
  static const warningTint = Color(0x1FD9A441);
  static const error = Color(0xFFC9473F);
  static const errorTint = Color(0x1AC9473F);
}

/// Mismos matices de marca que _Light, reequilibrados para contraste
/// sobre fondo oscuro (primary/accent algo más claros para seguir
/// funcionando como texto/iconos, no solo como relleno).
class _Dark {
  _Dark._();

  static const background = Color(0xFF0C1220);
  static const surface = Color(0xFF151F32);
  static const surfaceMuted = Color(0xFF1C2A42);
  static const border = Color(0xFF2B3A54);

  static const ink = Color(0xFFEDF1F7);
  static const inkMuted = Color(0xFFAAB5C8);
  static const inkFaint = Color(0xFF717F99);

  static const primary = Color(0xFF6B97C7);
  static const primaryStrong = Color(0xFF3E6188);
  static const primaryTint = Color(0x296B97C7);

  static const accent = Color(0xFFF0A740);
  static const accentStrong = Color(0xFFD9862A);
  static const accentTint = Color(0x29F0A740);

  static const success = Color(0xFF49C08D);
  static const successTint = Color(0x2949C08D);
  static const warning = Color(0xFFE8BC66);
  static const warningTint = Color(0x29E8BC66);
  static const error = Color(0xFFE2766B);
  static const errorTint = Color(0x29E2766B);
}

/// Radios y espaciado consistentes -- nunca un valor suelto.
class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
