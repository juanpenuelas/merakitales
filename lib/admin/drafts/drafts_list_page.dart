import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/skeleton_loader.dart';

class DraftsListPage extends StatefulWidget {
  const DraftsListPage({super.key});
  @override
  State<DraftsListPage> createState() => _DraftsListPageState();
}

class _DraftsListPageState extends State<DraftsListPage> {
  final _service = DraftsService();
  bool _creating = false;

  Future<void> _createNewDraft() async {
    setState(() => _creating = true);
    try {
      final draftId = await _service.createManualDraft(
        nameEs: 'Nuevo borrador',
        descriptionEs: '',
        specificationsEs: '',
        nameEn: 'New draft',
        descriptionEn: '',
        specificationsEn: '',
      );
      if (mounted) context.go('/drafts/workspace/$draftId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      selectedIndex: 1,
      title: 'Borradores',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: FilledButton.icon(
            onPressed: _creating ? null : _createNewDraft,
            icon: _creating 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add, size: 18),
            label: const Text('Nuevo Cuento'),
          ),
        ),
      ],
      child: StreamBuilder<List<Draft>>(
        stream: _service.streamDrafts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonLoader();
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final drafts = snap.data ?? [];
          final scheduledDrafts = drafts.where((d) => d.status == 'scheduled').toList()
            ..sort((a, b) => (a.scheduledAt ?? DateTime.now()).compareTo(b.scheduledAt ?? DateTime.now()));
          final pendingDrafts = drafts.where((d) => d.status != 'scheduled').toList()
            ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: Text('Próximos Lanzamientos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
              ),
              if (scheduledDrafts.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.calendar_today_outlined,
                    message: 'No hay lanzamientos programados.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList.separated(
                    itemCount: scheduledDrafts.length,
                    separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (c, i) => _DraftListItem(draft: scheduledDrafts[i], isScheduled: true),
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: Text('Borradores Pendientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
              ),
              if (pendingDrafts.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.note_add_outlined,
                    message: 'No hay borradores pendientes.\nPulsa "Nuevo Cuento" para crear uno.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList.separated(
                    itemCount: pendingDrafts.length,
                    separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (c, i) => _DraftListItem(draft: pendingDrafts[i], isScheduled: false),
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          );
        },
      ),
    );
  }
}

class _DraftListItem extends StatelessWidget {
  const _DraftListItem({required this.draft, required this.isScheduled});
  final Draft draft;
  final bool isScheduled;

  @override
  Widget build(BuildContext context) {
    final title = draft.nameEs.isNotEmpty ? draft.nameEs : draft.nameEn;
    return AppCard(
      onTap: () => context.go('/drafts/workspace/${draft.id}'),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: draft.imageUrl640.isNotEmpty
                ? Image.network(
                    draft.imageUrl640,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const _PlaceholderThumb(icon: Icons.broken_image_outlined),
                  )
                : const _PlaceholderThumb(icon: Icons.auto_stories_outlined),
          ),
          const SizedBox(width: AppSpacing.md),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : 'Sin título',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge.step(draft.step),
                    if (draft.retractedFromTaleId != null) StatusBadge.retracted(),
                    
                    if (isScheduled && draft.scheduledAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE), // violet-100
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Saldrá: ${_formatDateTime(draft.scheduledAt!)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else if (!isScheduled && draft.createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // slate-100
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _formatDate(draft.createdAt!),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour:$minute';
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 24, color: AppColors.primaryLight),
    );
  }
}
