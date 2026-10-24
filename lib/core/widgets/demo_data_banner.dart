// lib/core/widgets/demo_data_banner.dart
//
// Aviso en el dashboard mientras queden datos de ejemplo en la app --
// evita que alguien confunda cifras/clientes de muestra con su negocio
// real. Desaparece solo cuando ya no queda ningún registro con esDemo.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DemoDataBanner extends StatelessWidget {
  const DemoDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.accentStrong,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'Estás viendo datos de ejemplo (marcados con "DEMO") para '
              'explorar la app. Crea tus propios clientes y trabajos '
              'cuando quieras -- puedes borrar los de muestra en '
              'cualquier momento.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
