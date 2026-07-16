import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategoriesService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Category>> streamCategories() {
    return _db
        .collection('categories')
        .orderBy('sort_order')
        .snapshots()
        .map((qs) => qs.docs.map(Category.fromDoc).toList());
  }

  Future<void> createCategory({
    required String nameEs,
    required String nameEn,
    required String emoji,
    required String slug,
    required int sortOrder,
  }) async {
    await _db.collection('categories').add({
      'name_es': nameEs,
      'name_en': nameEn,
      'emoji': emoji,
      'slug': slug,
      'sort_order': sortOrder,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory({
    required String id,
    required String nameEs,
    required String nameEn,
    required String emoji,
    required String slug,
    required int sortOrder,
  }) async {
    await _db.collection('categories').doc(id).update({
      'name_es': nameEs,
      'name_en': nameEn,
      'emoji': emoji,
      'slug': slug,
      'sort_order': sortOrder,
    });
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }
}
