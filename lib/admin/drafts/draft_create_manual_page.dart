import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';

class DraftCreateManualPage extends StatefulWidget {
  const DraftCreateManualPage({super.key, this.draftId});
  final String? draftId;

  @override
  State<DraftCreateManualPage> createState() => _DraftCreateManualPageState();
}

class _DraftCreateManualPageState extends State<DraftCreateManualPage> {
  final _service = DraftsService();

  final _nameEsController = TextEditingController();
  final _descriptionEsController = TextEditingController();
  final _specificationsEsController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _specificationsEnController = TextEditingController();

  String? _draftId;
  Draft? _draft;
  bool _saving = false;
  bool _loadingExisting = false;
  bool _uploadingImage = false;
  double? _imageUploadProgress;
  bool _uploadingAudioEs = false;
  double? _audioEsProgress;
  bool _uploadingAudioEn = false;
  double? _audioEnProgress;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (_draftId != null) {
      _loadingExisting = true;
      _service.streamDraft(_draftId!).listen((draft) {
        if (!mounted || draft == null) return;
        final firstLoad = _draft == null;
        setState(() {
          _draft = draft;
          _loadingExisting = false;
          if (firstLoad) {
            _nameEsController.text = draft.nameEs;
            _descriptionEsController.text = draft.descriptionEs;
            _specificationsEsController.text = draft.specificationsEs;
            _nameEnController.text = draft.nameEn;
            _descriptionEnController.text = draft.descriptionEn;
            _specificationsEnController.text = draft.specificationsEn;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _nameEsController.dispose();
    _descriptionEsController.dispose();
    _specificationsEsController.dispose();
    _nameEnController.dispose();
    _descriptionEnController.dispose();
    _specificationsEnController.dispose();
    super.dispose();
  }

  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  bool get _textComplete =>
      _nameEsController.text.trim().isNotEmpty &&
      _descriptionEsController.text.trim().isNotEmpty &&
      _specificationsEsController.text.trim().isNotEmpty &&
      _nameEnController.text.trim().isNotEmpty &&
      _descriptionEnController.text.trim().isNotEmpty &&
      _specificationsEnController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_textComplete) return;
    setState(() => _saving = true);
    try {
      if (_draftId == null) {
        final id = await _service.createManualDraft(
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descriptionEsController.text.trim(),
          specificationsEs: _specificationsEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descriptionEnController.text.trim(),
          specificationsEn: _specificationsEnController.text.trim(),
        );
        _draftId = id;
        if (mounted) context.go('/drafts/manual/$id');
      } else {
        await _service.updateManualDraftText(
          draftId: _draftId!,
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descriptionEsController.text.trim(),
          specificationsEs: _specificationsEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descriptionEnController.text.trim(),
          specificationsEn: _specificationsEnController.text.trim(),
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrador guardado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_draftId == null) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (file.size > 15 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La imagen supera los 15MB')));
      return;
    }
    setState(() {
      _uploadingImage = true;
      _imageUploadProgress = 0;
    });
    try {
      final task = _service.uploadDraftImage(_draftId!, bytes);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          setState(() => _imageUploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
      await task;
      await _service.resizeDraftImage(_draftId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo imagen: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _imageUploadProgress = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadAudio(String lang) async {
    if (_draftId == null) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (file.size > 30 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El audio supera los 30MB')));
      return;
    }
    setState(() {
      if (lang == 'es') {
        _uploadingAudioEs = true;
        _audioEsProgress = 0;
      } else {
        _uploadingAudioEn = true;
        _audioEnProgress = 0;
      }
    });
    try {
      final task = _service.uploadDraftAudio(_draftId!, lang, bytes);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            if (lang == 'es') {
              _audioEsProgress = progress;
            } else {
              _audioEnProgress = progress;
            }
          });
        }
      });
      await task;
      final url = await task.snapshot.ref.getDownloadURL();
      final otherUrl = lang == 'es' ? (_draft?.audioUrlEn ?? '') : (_draft?.audioUrlEs ?? '');
      await _service.saveManualDraftAudioUrl(
        draftId: _draftId!,
        lang: lang,
        url: url,
        bothLangsPresent: otherUrl.isNotEmpty,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio subido')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo audio: $e')));
    } finally {
      if (mounted) {
        setState(() {
          if (lang == 'es') {
            _uploadingAudioEs = false;
            _audioEsProgress = null;
          } else {
            _uploadingAudioEn = false;
            _audioEnProgress = null;
          }
        });
      }
    }
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool showWordCount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: '$label *'),
          ),
          if (showWordCount) ...[
            const SizedBox(height: 4),
            Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (_wordCount(controller.text) > 0 &&
                (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600))
              const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _imageSection() {
    if (_draftId == null) {
      return const Text('Guarda el texto primero para poder subir la imagen.', style: TextStyle(color: Colors.grey));
    }
    final hasImage = _draft?.imageUrl.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _draft!.imageUrl,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_uploadingImage) LinearProgressIndicator(value: _imageUploadProgress),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadingImage ? null : _pickAndUploadImage,
          icon: const Icon(Icons.upload_file),
          label: Text(hasImage ? 'Reemplazar imagen' : 'Subir imagen'),
        ),
      ],
    );
  }

  Widget _audioSection(String lang) {
    final label = lang == 'es' ? 'Audio Español' : 'Audio English';
    final url = lang == 'es' ? (_draft?.audioUrlEs ?? '') : (_draft?.audioUrlEn ?? '');
    final uploading = lang == 'es' ? _uploadingAudioEs : _uploadingAudioEn;
    final progress = lang == 'es' ? _audioEsProgress : _audioEnProgress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(url.isEmpty ? 'Sin audio' : 'Audio subido ✓', style: const TextStyle(fontSize: 13)),
          if (uploading) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: (uploading || _draftId == null) ? null : () => _pickAndUploadAudio(lang),
            icon: const Icon(Icons.upload_file),
            label: Text(url.isEmpty ? 'Subir audio' : 'Reemplazar audio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear a mano'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/drafts')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Texto — Español', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEsController),
            _textField(label: 'Descripción', controller: _descriptionEsController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEsController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Texto — English', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEnController),
            _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _imageSection(),
            const Divider(height: 32),
            const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _audioSection('es'),
            _audioSection('en'),
            if (_draft?.step == 'audio')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/${_draftId!}'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver borrador completo →'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: (_textComplete && !_saving) ? _save : null,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_textComplete ? 'Guardar borrador' : 'Completa ambos idiomas para guardar'),
          ),
        ),
      ),
    );
  }
}
