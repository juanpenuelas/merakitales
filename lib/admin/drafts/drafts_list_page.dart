import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class DraftsListPage extends StatefulWidget {
  const DraftsListPage({super.key});
  @override
  State<DraftsListPage> createState() => _DraftsListPageState();
}

class _DraftsListPageState extends State<DraftsListPage> {
  final _service = DraftsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borradores'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/drafts/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo cuento'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/manual'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Crear a mano'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/published'),
                  icon: const Icon(Icons.public),
                  label: const Text('Publicados'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Draft>>(
        stream: _service.streamDrafts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final drafts = snap.data ?? [];
          if (drafts.isEmpty) {
            return const EmptyState(
              icon: Icons.note_add_outlined,
              message: 'No hay borradores pendientes.\nPulsa "Nuevo cuento" para crear uno.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: drafts.length,
            separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (c, i) {
              final d = drafts[i];
              return AppCard(
                onTap: () => context.go('/drafts/${d.id}'),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: d.imageUrl640.isNotEmpty
                          ? Image.network(
                              d.imageUrl640,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                            )
                          : Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.book)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nameEs.isNotEmpty ? d.nameEs : d.nameEn, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              StatusBadge.step(d.step),
                              if (d.retractedFromTaleId != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.retracted(),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                d.createdAt != null ? d.createdAt!.toLocal().toString() : '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
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
