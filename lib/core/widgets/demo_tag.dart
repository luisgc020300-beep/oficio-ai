// lib/core/widgets/demo_tag.dart
//
// Etiqueta discreta para marcar datos de ejemplo -- nunca debe poder
// confundirse con un cliente/trabajo/presupuesto/cita real que haya
// creado el usuario. Se usa en listas, fichas y en el aviso del
// dashboard (ver demo_data_banner.dart).
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DemoTag extends StatelessWidget {
  const DemoTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        'DEMO',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.accentStrong,
        ),
      ),
    );
  }
}
