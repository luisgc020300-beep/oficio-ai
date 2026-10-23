// lib/core/widgets/brand_mark.dart
//
// Identidad visual mínima de Oficio AI -- un monograma propio en vez del
// texto suelto que llevaba el AppBar del dashboard, para que la app se
// reconozca como un producto con marca, no como una plantilla sin
// personalizar.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, super.key});

  /// true para usarlo dentro de un AppBar (más pequeño, sin tagline).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tamano = compact ? 30.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryStrong],
            ),
            borderRadius: BorderRadius.circular(compact ? 9 : 12),
          ),
          alignment: Alignment.center,
          child: Text(
            'O',
            style: GoogleFonts.manrope(
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Text(
          'Oficio AI',
          style: GoogleFonts.manrope(
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
