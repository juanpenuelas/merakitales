import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/published_tale.dart';
import '../theme/app_spacing.dart';
import '../widgets/empty_state.dart';
import '../widgets/tale_row_card.dart';
import '../widgets/status_badge.dart';

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
                    return TaleRowCard(
                      onTap: () => context.go('/published/${t.taleId}'),
                      title: t.name,
                      imageUrl640: t.imageUrl640,
                      placeholder: Icons.public,
                      badges: [
                        StatusBadge.published(),
                        if (t.isPremiumTale) StatusBadge.premium(),
                      ],
                      trailing: TextButton.icon(
                        onPressed: () => _retract(t),
                        icon: const Icon(Icons.undo),
                        label: const Text('Retirar'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
