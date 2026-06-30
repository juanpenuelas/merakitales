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
  final _themeController = TextEditingController();
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await _service.generateDraft(theme: _themeController.text.trim().isEmpty ? null : _themeController.text.trim());
      _themeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() { _themeController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borradores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _themeController,
                    decoration: const InputDecoration(
                      labelText: 'Tema (opcional)',
                      hintText: 'amistad, valentía, naturaleza…',
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Draft>>(
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
                  return const Center(child: Text('No hay borradores pendientes.'));
                }
                return ListView.builder(
                  itemCount: drafts.length,
                  itemBuilder: (c, i) {
                    final d = drafts[i];
                    return ListTile(
                      leading: d.imageUrl640.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(d.imageUrl640, width: 56, height: 56, fit: BoxFit.cover))
                          : const Icon(Icons.book),
                      title: Text('${d.nameEs} / ${d.nameEn}'),
                      subtitle: Text(d.createdAt != null ? '${d.createdAt!.toLocal()}' : ''),
                      onTap: () => context.go('/drafts/${d.id}'),
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
