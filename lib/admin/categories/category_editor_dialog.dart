import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_spacing.dart';
import '../util/format.dart';

class CategoryFormResult {
  final String nameEs, nameEn, emoji, slug;
  final int sortOrder;
  CategoryFormResult({required this.nameEs, required this.nameEn, required this.emoji, required this.slug, required this.sortOrder});
}

Future<CategoryFormResult?> showCategoryEditor(BuildContext context, {Category? existing}) {
  return showDialog<CategoryFormResult>(
    context: context,
    builder: (_) => _CategoryEditorDialog(existing: existing),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.existing});
  final Category? existing;
  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nameEs, _nameEn, _emoji, _slug, _sort;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameEs = TextEditingController(text: e?.nameEs ?? '');
    _nameEn = TextEditingController(text: e?.nameEn ?? '');
    _emoji = TextEditingController(text: e?.emoji ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _sort = TextEditingController(text: (e?.sortOrder ?? 0).toString());
    _slugTouched = e != null;
    _nameEs.addListener(() {
      if (!_slugTouched) _slug.text = slugify(_nameEs.text);
    });
  }

  @override
  void dispose() {
    for (final c in [_nameEs, _nameEn, _emoji, _slug, _sort]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('cat_name_es'), controller: _nameEs, decoration: const InputDecoration(labelText: 'Nombre (ES)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_name_en'), controller: _nameEn, decoration: const InputDecoration(labelText: 'Nombre (EN)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_emoji'), controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_slug'), controller: _slug, onChanged: (_) => _slugTouched = true, decoration: const InputDecoration(labelText: 'Slug')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Orden')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('cat_save'),
          onPressed: () => Navigator.of(context).pop(CategoryFormResult(
            nameEs: _nameEs.text.trim(),
            nameEn: _nameEn.text.trim(),
            emoji: _emoji.text.trim(),
            slug: _slug.text.trim().isEmpty ? slugify(_nameEs.text) : _slug.text.trim(),
            sortOrder: int.tryParse(_sort.text) ?? 0,
          )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
