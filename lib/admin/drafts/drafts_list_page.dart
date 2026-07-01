import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/drafts/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo cuento'),
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
            return const Center(child: Text('No hay borradores pendientes. Pulsa "Nuevo cuento" para crear uno.'));
          }
          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (c, i) {
              final d = drafts[i];
              final stepLabel = switch (d.step) {
                'text' => '📝 Texto',
                'image' => '🖼️ Imagen',
                'audio' => '🎵 Audio',
                _ => d.step,
              };
              return ListTile(
                leading: d.imageUrl640.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          d.imageUrl640,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                        ),
                      )
                    : const Icon(Icons.book),
                title: Text('${d.nameEs.isNotEmpty ? d.nameEs : d.nameEn}'),
                subtitle: Text('$stepLabel · ${d.createdAt != null ? d.createdAt!.toLocal() : ''}'),
                trailing: d.retractedFromTaleId != null
                    ? const Chip(label: Text('retractado'), backgroundColor: Colors.orange)
                    : null,
                onTap: () => context.go('/drafts/${d.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
