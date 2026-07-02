import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';

class DraftDetailPage extends StatefulWidget {
  const DraftDetailPage({super.key, required this.draftId});
  final String draftId;
  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  final _service = DraftsService();
  bool _es = true;
  bool _busy = false;

  Future<void> _approve(String id) async {
    setState(() => _busy = true);
    try {
      final taleId = await _service.approveDraft(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicado como tale_id=$taleId')));
        context.go('/drafts');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busy = true);
    try {
      await _service.rejectDraft(id);
      if (mounted) context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Draft?>(
      stream: _service.streamDraft(widget.draftId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.hasData || snap.data == null) return const Scaffold(body: Center(child: Text('Borrador no encontrado')));
        final d = snap.data!;
        final name = _es ? d.nameEs : d.nameEn;
        final desc = _es ? d.descriptionEs : d.descriptionEn;
        final spec = _es ? d.specificationsEs : d.specificationsEn;
        final audio = _es ? d.audioUrlEs : d.audioUrlEn;
        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    StatusBadge.step(d.step),
                    if (d.retractedFromTaleId != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge.retracted(),
                      const SizedBox(width: 4),
                      Text('de tale_id=${d.retractedFromTaleId}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              ToggleButtons(
                isSelected: [_es, !_es],
                onPressed: (i) => setState(() => _es = i == 0),
                children: const [Text('ES'), Text('EN')],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                d.imageUrl,
                                errorBuilder: (c, e, s) => Container(
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(desc),
                                const SizedBox(height: AppSpacing.md),
                                Text('Texto del cuento', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(spec, style: const TextStyle(fontSize: 18, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Audio (${_es ? 'ES' : 'EN'})", style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                if (audio.isNotEmpty)
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse(audio)),
                                    child: const Row(children: [Icon(Icons.play_circle, size: 32), SizedBox(width: 8), Text('Reproducir audio')]),
                                  )
                                else
                                  const Text('Sin audio'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (d.step != 'audio')
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Este borrador aún no ha completado los 3 pasos (texto, imagen, audio ES/EN) y no se puede publicar todavía.',
                                style: TextStyle(color: AppColors.warning, fontSize: 12),
                              ),
                            ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(d.id),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (d.step == 'audio')
                                FilledButton.icon(
                                  onPressed: () => _approve(d.id),
                                  icon: const Icon(Icons.publish),
                                  label: const Text('Aprobar y publicar'),
                                ),
                            ],
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
