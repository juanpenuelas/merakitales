import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.icon, required this.label, required this.color, required this.bgColor});

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  factory StatusBadge.step(String step) {
    switch (step) {
      case 'audio':
        return const StatusBadge(
          icon: Icons.graphic_eq_rounded,
          label: 'Audio',
          color: AppColors.success,
          bgColor: AppColors.successSurface,
        );
      case 'image':
        return const StatusBadge(
          icon: Icons.image_rounded,
          label: 'Imagen',
          color: AppColors.primary,
          bgColor: AppColors.primarySurface,
        );
      case 'text':
      default:
        return const StatusBadge(
          icon: Icons.edit_note_rounded,
          label: 'Texto',
          color: AppColors.textSecondary,
          bgColor: Color(0xFFF1F5F9),
        );
    }
  }

  factory StatusBadge.retracted() => const StatusBadge(
        icon: Icons.history_rounded,
        label: 'Retractado',
        color: AppColors.warning,
        bgColor: AppColors.warningSurface,
      );

  factory StatusBadge.published() => const StatusBadge(
        icon: Icons.public_rounded,
        label: 'Publicado',
        color: AppColors.success,
        bgColor: AppColors.successSurface,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
