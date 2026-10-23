// lib/core/theme/app_colors.dart
//
// Paleta de Oficio AI: azul pizarra (confianza, profesional) + ámbar
// (oficio, trabajo manual, calidez) como único acento de llamada a la
// acción. Sin degradados, sin colores decorativos sueltos por pantalla.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

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
