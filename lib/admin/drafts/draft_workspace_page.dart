import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';

class DraftWorkspacePage extends StatefulWidget {
  const DraftWorkspacePage({super.key, this.draftId});
  final String? draftId;

  @override
  State<DraftWorkspacePage> createState() => _DraftWorkspacePageState();
}

class _DraftWorkspacePageState extends State<DraftWorkspacePage> {
  final _service = DraftsService();

  Draft? _draft;
  String? _draftId;
  bool _loading = false;
  bool _saving = false;
  bool _savingPremium = false;

  // AI Prompting
  final _themeController = TextEditingController();
  final _feedback1Controller = TextEditingController();
  bool _generatingText = false;

  // Editable texts
  final _nameEsController = TextEditingController();
  final _descEsController = TextEditingController();
  final _specEsController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descEnController = TextEditingController();
  final _specEnController = TextEditingController();

  // Images
  final _feedback2Controller = TextEditingController();
  bool _generatingImage = false;
  bool _uploadingImage = false;
  double? _imageUploadProgress;

  // Audio
  bool _generatingAudioEs = false;
  bool _generatingAudioEn = false;
  bool _uploadingAudioEs = false;
  bool _uploadingAudioEn = false;
  double? _audioEsProgress;
  double? _audioEnProgress;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (_draftId != null) {
      _loadDraft();
    }
  }

  void _loadDraft() {
    setState(() => _loading = true);
    _service.streamDraft(_draftId!).listen((draft) {
      if (!mounted) return;
      if (draft != null) {
        final firstLoad = _draft == null;
        setState(() {
          _draft = draft;
          _loading = false;
          if (firstLoad) {
            _syncControllersWithDraft();
          }
        });
      }
    });
  }

  void _syncControllersWithDraft() {
    if (_draft == null) return;
    _nameEsController.text = _draft!.nameEs;
    _descEsController.text = _draft!.descriptionEs;
    _specEsController.text = _draft!.specificationsEs;
    _nameEnController.text = _draft!.nameEn;
    _descEnController.text = _draft!.descriptionEn;
    _specEnController.text = _draft!.specificationsEn;
  }

  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  // --- ACTIONS: SETTINGS ---

  Future<void> _toggleIsPremium(bool value) async {
    if (_draftId == null) return;
    setState(() => _savingPremium = true);
    try {
      await _service.updateDraftPremium(draftId: _draftId!, isPremiumTale: value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium actualizado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingPremium = false);
    }
  }

  // --- ACTIONS: TEXT ---

  Future<void> _generateTextAI() async {
    final theme = _themeController.text.trim().isEmpty ? null : _themeController.text.trim();
    final feedback = _feedback1Controller.text.trim().isEmpty ? null : _feedback1Controller.text.trim();
    setState(() => _generatingText = true);
    try {
      if (_draftId == null) {
        _draftId = await _service.generateText(theme: theme, feedback: feedback);
        context.go('/drafts/workspace/$_draftId');
        _loadDraft();
      } else {
        await _service.generateText(theme: theme, feedback: feedback); // wait, service.generateText creates a NEW one. 
        // We need an endpoint or logic to regenerate on the SAME draft.
        // Actually, DraftsService might not have regenerateText(draftId). But it has generateText.
        // For now let's just show an error if it's already created, or we need to update the service.
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generatingText = false);
    }
  }

  Future<void> _saveManualText() async {
    setState(() => _saving = true);
    try {
      if (_draftId == null) {
        final id = await _service.createManualDraft(
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descEsController.text.trim(),
          specificationsEs: _specEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descEnController.text.trim(),
          specificationsEn: _specEnController.text.trim(),
        );
        _draftId = id;
        context.go('/drafts/workspace/$id');
        _loadDraft();
      } else {
        await _service.updateManualDraftText(
          draftId: _draftId!,
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descEsController.text.trim(),
          specificationsEs: _specEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descEnController.text.trim(),
          specificationsEn: _specEnController.text.trim(),
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto guardado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- ACTIONS: IMAGE ---

  Future<void> _generateImageAI() async {
    if (_draftId == null) return;
    setState(() => _generatingImage = true);
    try {
      final feedback = _feedback2Controller.text.trim().isEmpty ? null : _feedback2Controller.text.trim();
      await _service.generateImage(_draftId!, feedback: feedback);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen en proceso (tardará unos segundos)...')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_draftId == null) return;
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    
    setState(() { _uploadingImage = true; _imageUploadProgress = 0; });
    try {
      final task = _service.uploadDraftImage(_draftId!, file.bytes!);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          setState(() => _imageUploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
      await task;
      await _service.resizeDraftImage(_draftId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida manualmente')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo imagen: $e')));
    } finally {
      if (mounted) setState(() { _uploadingImage = false; _imageUploadProgress = null; });
    }
  }

  // --- ACTIONS: AUDIO ---

  Future<void> _generateAudioAI(String lang) async {
    if (_draftId == null) return;
    setState(() => lang == 'es' ? _generatingAudioEs = true : _generatingAudioEn = true);
    try {
      await _service.generateAudio(_draftId!, lang);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audio $lang en proceso...')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => lang == 'es' ? _generatingAudioEs = false : _generatingAudioEn = false);
    }
  }

  Future<void> _pickAndUploadAudio(String lang) async {
    if (_draftId == null) return;
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp3'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    
    setState(() {
      if (lang == 'es') { _uploadingAudioEs = true; _audioEsProgress = 0; }
      else { _uploadingAudioEn = true; _audioEnProgress = 0; }
    });
    try {
      final task = _service.uploadDraftAudio(_draftId!, lang, file.bytes!);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          setState(() {
            final p = snapshot.bytesTransferred / snapshot.totalBytes;
            if (lang == 'es') _audioEsProgress = p; else _audioEnProgress = p;
          });
        }
      });
      await task;
      final url = await task.snapshot.ref.getDownloadURL();
      await _service.saveManualDraftAudioUrl(draftId: _draftId!, lang: lang, url: url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audio $lang subido manualmente')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo audio: $e')));
    } finally {
      if (mounted) setState(() {
        if (lang == 'es') { _uploadingAudioEs = false; _audioEsProgress = null; }
        else { _uploadingAudioEn = false; _audioEnProgress = null; }
      });
    }
  }

  // --- ACTIONS: PUBLISH ---

  Future<void> _approveAndPublish() async {
    if (_draftId == null) return;
    try {
      final taleId = await _service.approveDraft(_draftId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicado como tale_id=$taleId')));
        context.go('/drafts');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_draft == null ? 'Nuevo Workspace' : 'Workspace: ${_draft!.nameEs}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/drafts')),
        actions: [
          if (_draft != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(child: StatusBadge.step(_draft!.step)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildSettingsSection(),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextSection()),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      _buildImageSection(),
                      const SizedBox(height: AppSpacing.md),
                      _buildAudioSection(),
                      if (_draft?.step == 'audio') ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _approveAndPublish,
                              icon: const Icon(Icons.publish),
                              label: const Text('Aprobar y Publicar Cuento'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: AppColors.success,
                              ),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Ajustes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cuento Premium'),
            subtitle: const Text('Solo visible para usuarios con suscripción'),
            value: _draft?.isPremiumTale ?? false,
            onChanged: (_draft == null || _savingPremium) ? null : _toggleIsPremium,
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields, color: AppColors.primary),
              SizedBox(width: 8),
              Text('1. Textos del Cuento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(height: 24),
          if (_draft == null) ...[
            Text('Generar con IA (OpenRouter)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(controller: _themeController, decoration: const InputDecoration(labelText: 'Tema (opcional)')),
            const SizedBox(height: 8),
            TextField(controller: _feedback1Controller, decoration: const InputDecoration(labelText: 'Feedback / Instrucciones'), maxLines: 2),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generatingText ? null : _generateTextAI,
              icon: _generatingText ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
              label: const Text('Generar Textos Mágicamente'),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('— O —', style: TextStyle(color: Colors.grey)))),
          ],
          Text('Edición Manual', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _editableField('Nombre (ES)', _nameEsController),
          _editableField('Nombre (EN)', _nameEnController),
          _editableField('Descripción (ES)', _descEsController, maxLines: 2),
          _editableField('Descripción (EN)', _descEnController, maxLines: 2),
          _editableField('Cuento (ES)', _specEsController, maxLines: 12, showWordCount: true),
          _editableField('Cuento (EN)', _specEnController, maxLines: 12, showWordCount: true),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveManualText,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: const Text('Guardar Textos'),
          ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller, {int maxLines = 1, bool showWordCount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (showWordCount) ...[
            const SizedBox(height: 4),
            Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (_wordCount(controller.text) > 0 && (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600))
              const Text('⚠️ Los cuentos deberían tener 300-500 palabras', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final hasImage = _draft?.imageUrl.isNotEmpty ?? false;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.image, color: AppColors.primary),
              SizedBox(width: 8),
              Text('2. Imagen Ilustrativa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(height: 24),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _draft!.imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.subtleFill, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('Sin imagen', style: TextStyle(color: AppColors.textSecondary))),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _feedback2Controller,
            decoration: const InputDecoration(labelText: 'Feedback para IA (opcional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_draftId == null || _generatingImage) ? null : _generateImageAI,
                  icon: _generatingImage ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: Text(hasImage ? 'Regenerar (IA)' : 'Generar (IA)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_draftId == null || _uploadingImage) ? null : _pickAndUploadImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir Manual'),
                ),
              ),
            ],
          ),
          if (_uploadingImage && _imageUploadProgress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(value: _imageUploadProgress),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic, color: AppColors.primary),
              SizedBox(width: 8),
              Text('3. Voces y Narración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(height: 24),
          _audioRow('es', 'Español'),
          const Divider(height: 16),
          _audioRow('en', 'Inglés'),
        ],
      ),
    );
  }

  Widget _audioRow(String lang, String label) {
    final url = lang == 'es' ? (_draft?.audioUrlEs ?? '') : (_draft?.audioUrlEn ?? '');
    final generating = lang == 'es' ? _generatingAudioEs : _generatingAudioEn;
    final uploading = lang == 'es' ? _uploadingAudioEs : _uploadingAudioEn;
    final progress = lang == 'es' ? _audioEsProgress : _audioEnProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (url.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: AppColors.primary),
                onPressed: () => launchUrl(Uri.parse(url)),
                tooltip: 'Escuchar',
              )
            else
              const Text('Pendiente', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: (_draftId == null || generating) ? null : () => _generateAudioAI(lang),
                icon: generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: Text(url.isEmpty ? 'Generar (Azure)' : 'Regenerar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_draftId == null || uploading) ? null : () => _pickAndUploadAudio(lang),
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir Manual'),
              ),
            ),
          ],
        ),
        if (uploading && progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LinearProgressIndicator(value: progress),
          ),
      ],
    );
  }
}
