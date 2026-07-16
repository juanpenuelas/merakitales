import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  factory StatusBadge.step(String step) {
    switch (step) {
      case 'image':
        return const StatusBadge(icon: Icons.image_outlined, label: 'Imagen', color: AppColors.primary);
      case 'audio':
        return const StatusBadge(icon: Icons.graphic_eq, label: 'Audio', color: AppColors.success);
      case 'text':
      default:
        return const StatusBadge(icon: Icons.edit_note, label: 'Texto', color: AppColors.textSecondary);
    }
  }

  factory StatusBadge.retracted() =>
      const StatusBadge(icon: Icons.history, label: 'Retractado', color: AppColors.warning);

  factory StatusBadge.premium() =>
      const StatusBadge(icon: Icons.star, label: 'Premium', color: AppColors.warning);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
