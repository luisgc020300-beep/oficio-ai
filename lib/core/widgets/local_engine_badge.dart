// lib/core/widgets/local_engine_badge.dart
//
// Mismo aviso visual que ya usa AssistantScreen -- debe dejar claro en
// cualquier pantalla donde aparezca que no hay ninguna IA real detrás
// todavía, solo un motor de reglas local.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LocalEngineBadge extends StatelessWidget {
  const LocalEngineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(
        Icons.science_outlined,
        size: 16,
        color: AppColors.accentStrong,
      ),
      label: const Text('Motor local de demostración -- sin IA real todavía'),
      backgroundColor: AppColors.accentTint,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: AppColors.accentStrong,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
