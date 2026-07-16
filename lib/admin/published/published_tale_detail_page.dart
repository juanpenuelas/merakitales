import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/published_tale.dart';

class PublishedTaleDetailPage extends StatefulWidget {
  const PublishedTaleDetailPage({super.key, required this.taleId});
  final int taleId;
  @override
  State<PublishedTaleDetailPage> createState() => _PublishedTaleDetailPageState();
}

class _PublishedTaleDetailPageState extends State<PublishedTaleDetailPage> {
  final _service = DraftsService();
  bool _es = true;
  bool _retracting = false;
  late Future<PublishedTaleFull> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPublishedTale(widget.taleId);
  }

  Future<void> _retract() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar cuento'),
        content: const Text('¿Seguro que quieres retirarlo? Volverá a borradores para que puedas editarlo y republicarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _retracting = true);
    try {
      final draftId = await _service.retractTale(widget.taleId);
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
    return FutureBuilder<PublishedTaleFull>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/published'))),
            body: Center(child: Text('Error: ${snap.error ?? "cuento no encontrado"}')),
          );
        }
        final t = snap.data!;
        final name = _es ? t.nameEs : t.nameEn;
        final desc = _es ? t.descriptionEs : t.descriptionEn;
        final spec = _es ? t.specificationsEs : t.specificationsEn;
        final audio = _es ? t.audioUrlEs : t.audioUrlEn;
        return Scaffold(
          appBar: AppBar(
            title: Text(name.isNotEmpty ? name : 'tale_id=${t.taleId}'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/published')),
            actions: [
              ToggleButtons(
                isSelected: [_es, !_es],
                onPressed: (i) => setState(() => _es = i == 0),
                children: const [Text('ES'), Text('EN')],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _retracting
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                t.imageUrl,
                                errorBuilder: (c, e, s) => Container(
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text('tale_id=${t.taleId}', style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
                          Text(desc),
                          const SizedBox(height: 16),
                          Text('Texto del cuento', style: Theme.of(context).textTheme.titleSmall),
                          Text(spec, style: const TextStyle(fontSize: 18, height: 1.5)),
                          const SizedBox(height: 16),
                          Text("Audio (${_es ? 'ES' : 'EN'})", style: Theme.of(context).textTheme.titleSmall),
                          if (audio.isNotEmpty)
                            InkWell(
                              onTap: () => launchUrl(Uri.parse(audio)),
                              child: const Row(children: [Icon(Icons.play_circle, size: 32), SizedBox(width: 8), Text('Reproducir audio')]),
                            )
                          else
                            const Text('Sin audio'),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _retract,
                            icon: const Icon(Icons.undo),
                            label: const Text('Retirar de la app'),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
