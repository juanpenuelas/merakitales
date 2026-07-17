import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_spacing.dart';
import '../util/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/tale_row_card.dart';

class DraftsListPage extends StatefulWidget {
  const DraftsListPage({super.key});
  @override
  State<DraftsListPage> createState() => _DraftsListPageState();
}

class _DraftsListPageState extends State<DraftsListPage> {
  final _service = DraftsService();
  String _filter = 'pending';

  List<String> get _statuses {
    switch (_filter) {
      case 'scheduled': return ['scheduled'];
      case 'all': return ['pending', 'scheduled'];
      case 'pending':
      default: return ['pending'];
    }
  }

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
                  onPressed: () => context.go('/drafts/workspace'),
                  icon: const Icon(Icons.add),
                  label: const Text('Workspace (IA y Manual)'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/categories'),
                  icon: const Icon(Icons.category),
                  label: const Text('Categorías'),
                ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(label: const Text('Todos'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
                ChoiceChip(label: const Text('Pendientes'), selected: _filter == 'pending', onSelected: (_) => setState(() => _filter = 'pending')),
                ChoiceChip(label: const Text('Programados'), selected: _filter == 'scheduled', onSelected: (_) => setState(() => _filter = 'scheduled')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Draft>>(
              stream: _service.streamDraftsByStatuses(_statuses),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final drafts = snap.data ?? [];
                if (drafts.isEmpty) {
                  return EmptyState(
                    icon: Icons.note_add_outlined,
                    message: _filter == 'scheduled'
                        ? 'No hay borradores programados.'
                        : 'No hay borradores pendientes.\nPulsa "Workspace" para crear uno.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: drafts.length,
                  separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (c, i) {
                    final d = drafts[i];
                    final badges = <Widget>[
                      StatusBadge.step(d.step),
                      if (d.status == 'scheduled') StatusBadge.scheduled(),
                      if (d.isPremiumTale) StatusBadge.premium(),
                      if (d.retractedFromTaleId != null) StatusBadge.retracted(),
                      if (d.status == 'scheduled' && d.scheduledAt != null)
                        Text('Programado · ${formatScheduled(d.scheduledAt!.toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (d.status != 'scheduled' && d.createdAt != null)
                        Text(d.createdAt!.toLocal().toString(), style: Theme.of(context).textTheme.bodySmall),
                    ];
                    return TaleRowCard(
                      onTap: () => context.go('/drafts/workspace/${d.id}'),
                      title: d.nameEs.isNotEmpty ? d.nameEs : d.nameEn,
                      imageUrl640: d.imageUrl640,
                      placeholder: Icons.book,
                      badges: badges,
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
