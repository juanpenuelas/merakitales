import 'package:flutter/material.dart';
import '../services/categories_service.dart';
import '../models/category.dart';
// removed

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _service = CategoriesService();

  Future<void> _createCategory() async {
    // A simplified creation logic, hardcoded for now, real implementation would show a dialog
    await _service.createCategory(
      nameEs: 'Nueva Categoría',
      nameEn: 'New Category',
      emoji: '🏷️',
      slug: 'new-category',
      sortOrder: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createCategory,
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _service.deleteCategory(cat.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
