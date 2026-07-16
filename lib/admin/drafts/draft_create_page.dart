import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';

class DraftCreatePage extends StatefulWidget {
  const DraftCreatePage({super.key});
  @override
  State<DraftCreatePage> createState() => _DraftCreatePageState();
}

class _DraftCreatePageState extends State<DraftCreatePage> {
  final _service = DraftsService();

  // Step 1 state
  final _themeController = TextEditingController();
  final _feedback1Controller = TextEditingController();
  bool _generatingText = false;
  Draft? _draft; // populated once text is generated

  // Step 2 state
  final _feedback2Controller = TextEditingController();
  bool _generatingImage = false;

  // Step 3 state
  final _feedback3Controller = TextEditingController();
  bool _generatingAudioEs = false;
  bool _generatingAudioEn = false;

  int _wordCount(String s) => s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  Future<void> _generateText() async {
    final theme = _themeController.text.trim().isEmpty ? null : _themeController.text.trim();
    final feedback = _feedback1Controller.text.trim().isEmpty ? null : _feedback1Controller.text.trim();
    setState(() => _generatingText = true);
    try {
      final draftId = await _service.generateText(theme: theme, feedback: feedback);
      if (!mounted) return;
      final draft = await _service.streamDraft(draftId).firstWhere((d) => d != null).timeout(const Duration(seconds: 60));
      if (!mounted) return;
      setState(() => _draft = draft);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generatingText = false);
    }
  }

  Future<void> _regenerateText() async {
    await _generateText();
  }

  Future<void> _approveTextAndGenerateImage() async {
    if (_draft == null) return;
    setState(() => _generatingImage = true);
    try {
      await _service.generateImage(_draft!.id);
      if (!mounted) return;
      final updated = await _service.streamDraft(_draft!.id).firstWhere((d) => d?.step == 'image' || d?.step == 'audio').timeout(const Duration(seconds: 120));
      if (!mounted) return;
      setState(() => _draft = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _regenerateImage() async {
    if (_draft == null) return;
    final feedback = _feedback2Controller.text.trim().isEmpty ? null : _feedback2Controller.text.trim();
    setState(() => _generatingImage = true);
    try {
      await _service.generateImage(_draft!.id, feedback: feedback);
      if (!mounted) return;
      final updated = await _service.streamDraft(_draft!.id).firstWhere((d) => d?.step == 'image' || d?.step == 'audio').timeout(const Duration(seconds: 120));
      if (!mounted) return;
      setState(() => _draft = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _generateAudio(String lang) async {
    if (_draft == null) return;
    setState(() => lang == 'es' ? _generatingAudioEs = true : _generatingAudioEn = true);
    try {
      await _service.generateAudio(_draft!.id, lang);
      if (!mounted) return;
      final updated = await _service.streamDraft(_draft!.id)
          .firstWhere((d) => (lang == 'es' ? d?.audioUrlEs : d?.audioUrlEn)?.isNotEmpty == true)
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      setState(() => _draft = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => lang == 'es' ? _generatingAudioEs = false : _generatingAudioEn = false);
    }
  }

  Future<void> _saveDraftText(String lang, String newText) async {
    if (_draft == null) return;
    try {
      await _service.updateDraftText(_draft!.id, lang, newText);
      if (!mounted) return;
      final updated = await _service.streamDraft(_draft!.id).first;
      if (!mounted || updated == null) return;
      setState(() => _draft = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveAndPublish() async {
    if (_draft == null) return;
    try {
      final taleId = await _service.approveDraft(_draft!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicado como tale_id=$taleId')));
      context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _themeController.dispose();
    _feedback1Controller.dispose();
    _feedback2Controller.dispose();
    _feedback3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/drafts'),
        ),
      ),
      body: _draft == null ? _buildStep1() : _buildLaterSteps(),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paso 1: Texto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tema (opcional) y feedback para la IA (opcional).'),
          const SizedBox(height: 16),
          TextField(
            controller: _themeController,
            decoration: const InputDecoration(labelText: 'Tema', hintText: 'amistad, valentía, naturaleza…'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback1Controller,
            decoration: const InputDecoration(labelText: 'Feedback (opcional)', hintText: 'hazlo más corto, el protagonista debe ser un oso…'),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _generatingText ? null : _generateText,
            icon: _generatingText
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Generar texto'),
          ),
        ],
      ),
    );
  }

  Widget _buildLaterSteps() {
    final d = _draft!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Cuento: ${d.nameEs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (d.retractedFromTaleId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Retractado de tale_id=${d.retractedFromTaleId}', style: const TextStyle(color: Colors.orange)),
            ),
          const Divider(height: 32),

          // Step 1: Text (editable)
          const Text('Paso 1: Texto (editable)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _editableTextField(
            label: 'Cuento en español',
            initial: d.specificationsEs,
            onChanged: (v) => d.specificationsEs.length,
            onSaved: (newText) => _saveDraftText('es', newText),
          ),
          const SizedBox(height: 12),
          _editableTextField(
            label: 'Cuento en inglés',
            initial: d.specificationsEn,
            onChanged: (v) => v.length,
            onSaved: (newText) => _saveDraftText('en', newText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback1Controller,
            decoration: const InputDecoration(labelText: 'Feedback para regenerar', hintText: 'hazlo más largo, cambia el protagonista…'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _generatingText ? null : _regenerateText,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerar texto con feedback'),
          ),

          const Divider(height: 32),

          // Step 2: Image
          const Text('Paso 2: Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (d.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(d.imageUrl, fit: BoxFit.cover, height: 200, width: double.infinity),
            )
          else
            const Text('(sin imagen aún)'),
          const SizedBox(height: 8),
          TextField(
            controller: _feedback2Controller,
            decoration: const InputDecoration(labelText: 'Feedback para regenerar imagen', hintText: 'más brillante, sin fondo, personaje a la izquierda…'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (d.imageUrl.isEmpty)
                FilledButton.icon(
                  onPressed: _generatingImage ? null : _approveTextAndGenerateImage,
                  icon: _generatingImage
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image),
                  label: const Text('Aprobar texto y generar imagen'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _generatingImage ? null : _regenerateImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerar imagen'),
                ),
            ],
          ),

          const Divider(height: 32),

          // Step 3: Audio
          const Text('Paso 3: Audio', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _audioRow('es', d.audioUrlEs, _generatingAudioEs),
          const SizedBox(height: 8),
          _audioRow('en', d.audioUrlEn, _generatingAudioEn),
          const SizedBox(height: 16),
          if (d.audioUrlEs.isNotEmpty && d.audioUrlEn.isNotEmpty)
            FilledButton.icon(
              onPressed: _approveAndPublish,
              icon: const Icon(Icons.publish),
              label: const Text('Aprobar y publicar'),
            ),
        ],
      ),
    );
  }

  Widget _editableTextField({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
    required Future<void> Function(String) onSaved,
  }) {
    return StatefulBuilder(builder: (context, setLocal) {
      final controller = TextEditingController(text: initial);
      controller.addListener(() => onChanged(controller.text));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            maxLines: 8,
          ),
          const SizedBox(height: 4),
          Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600)
            const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () async {
              await onSaved(controller.text);
              if (mounted) setLocal(() {});
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      );
    });
  }

  Widget _audioRow(String lang, String url, bool busy) {
    final langLabel = lang == 'es' ? 'Español' : 'English';
    return Row(
      children: [
        Expanded(
          child: Text(
            url.isEmpty ? '🎵 Audio $langLabel (pendiente)' : '🎵 Audio $langLabel ✓',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        if (url.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => launchUrl(Uri.parse(url)),
            tooltip: 'Escuchar',
          ),
        OutlinedButton(
          onPressed: busy ? null : () => _generateAudio(lang),
          child: busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(url.isEmpty ? 'Generar' : 'Regenerar'),
        ),
      ],
    );
  }
}
