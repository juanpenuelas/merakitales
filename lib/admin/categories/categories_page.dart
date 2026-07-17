import 'package:flutter/material.dart';
import '../services/categories_service.dart';
import '../models/category.dart';
import 'category_editor_dialog.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _service = CategoriesService();

  Future<void> _create() async {
    final r = await showCategoryEditor(context);
    if (r == null) return;
    await _service.createCategory(nameEs: r.nameEs, nameEn: r.nameEn, emoji: r.emoji, slug: r.slug, sortOrder: r.sortOrder);
  }

  Future<void> _edit(Category cat) async {
    final r = await showCategoryEditor(context, existing: cat);
    if (r == null) return;
    await _service.updateCategory(id: cat.id, nameEs: r.nameEs, nameEn: r.nameEn, emoji: r.emoji, slug: r.slug, sortOrder: r.sortOrder);
  }

  Future<void> _delete(Category cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat.nameEs}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await _service.deleteCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _create,
          )
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: _service.streamCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final categories = snapshot.data ?? [];
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(cat.nameEs),
                subtitle: Text(cat.slug),
                onTap: () => _edit(cat),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(cat),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
