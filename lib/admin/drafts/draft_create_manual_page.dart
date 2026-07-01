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
