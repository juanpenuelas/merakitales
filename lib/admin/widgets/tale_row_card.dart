import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

class TaleRowCard extends StatelessWidget {
  const TaleRowCard({
    super.key,
    required this.title,
    required this.imageUrl640,
    required this.badges,
    this.trailing,
    this.onTap,
    this.placeholder = Icons.book,
  });

  final String title;
  final String imageUrl640;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData placeholder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl640.isNotEmpty
              ? Image.network(imageUrl640, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
              : Container(width: 56, height: 56, color: Colors.grey.shade200, child: Icon(placeholder)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(spacing: AppSpacing.sm, runSpacing: 4, children: badges),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
