import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_card.dart';
import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../util/format.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DraftsService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Pendientes',
                    query: FirebaseFirestore.instance.collection('tale_drafts').where('status', isEqualTo: 'pending'),
                    icon: Icons.edit_document,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Programados',
                    query: FirebaseFirestore.instance.collection('tale_drafts').where('status', isEqualTo: 'scheduled'),
                    icon: Icons.schedule,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Publicados',
                    query: FirebaseFirestore.instance.collection('tales').where('lang', isEqualTo: 'es'),
                    icon: Icons.library_books,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Próximas publicaciones',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Draft>>(
              stream: service.streamDraftsByStatuses(['scheduled']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonLoader(width: double.infinity, height: 80);
                }
                if (snapshot.hasError) {
                  return Text('Error', style: TextStyle(color: AppColors.destructive));
                }
                final drafts = snapshot.data ?? const <Draft>[];
                if (drafts.isEmpty) {
                  return Text(
                    'No hay publicaciones programadas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  );
                }
                final items = [...drafts]
                  ..sort((a, b) => (a.scheduledAt ?? DateTime(9999)).compareTo(b.scheduledAt ?? DateTime(9999)));
                return Column(
                  children: [
                    for (final d in items) ...[
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.nameEs,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (d.scheduledAt != null)
                              Text(
                                formatScheduled(d.scheduledAt!.toLocal()),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Acciones Rápidas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionCard(
                  context,
                  title: 'Workspace (Borradores)',
                  description: 'Genera con IA o escribe manualmente un cuento nuevo',
                  icon: Icons.auto_awesome,
                  onTap: () => context.go('/drafts/workspace'),
                ),
                const SizedBox(width: 16),
                _buildActionCard(
                  context,
                  title: 'Categorías',
                  description: 'Crea y organiza las categorías de los cuentos',
                  icon: Icons.local_offer_outlined,
                  onTap: () => context.go('/categories'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required Query query, required IconData icon, required Color color}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<AggregateQuerySnapshot>(
              stream: query.count().get().asStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonLoader(width: 60, height: 40);
                }
                if (snapshot.hasError) {
                  return Text('Error', style: TextStyle(color: AppColors.destructive));
                }
                final count = snapshot.data?.count ?? 0;
                return Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String description, required IconData icon, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.subtleFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
