import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/published_tale.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class PublishedListPage extends StatefulWidget {
  const PublishedListPage({super.key});
  @override
  State<PublishedListPage> createState() => _PublishedListPageState();
}

class _PublishedListPageState extends State<PublishedListPage> {
  final _service = DraftsService();
  bool _retracting = false;

  Future<void> _retract(PublishedTale tale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar cuento'),
        content: Text('¿Seguro que quieres retirar "${tale.name}"? Volverá a borradores para que puedas editarlo y republicarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _retracting = true);
    try {
      final draftId = await _service.retractTale(tale.taleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retractado como draft $draftId')));
      context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _retracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicados'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/drafts'),
        ),
      ),
      body: _retracting
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<PublishedTale>>(
              stream: _service.streamPublished(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final tales = snap.data ?? [];
                if (tales.isEmpty) {
                  return const EmptyState(
                    icon: Icons.public_off,
                    message: 'No hay cuentos publicados.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: tales.length,
                  separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (c, i) {
                    final t = tales[i];
                    return AppCard(
                      onTap: () => context.go('/published/${t.taleId}'),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: t.imageUrl640.isNotEmpty
                                ? Image.network(
                                    t.imageUrl640,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                                  )
                                : Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.public)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'tale_id=${t.taleId} · ${t.createdAt != null ? t.createdAt!.toLocal() : ''}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _retract(t),
                            icon: const Icon(Icons.undo),
                            label: const Text('Retirar'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
