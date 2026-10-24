// lib/core/widgets/stat_tile.dart
//
// Indicador numérico del panel principal -- icono circular + valor grande
// + etiqueta, mismo patrón en toda la fila de KPIs del dashboard.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tileColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: tileColor),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 22,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
