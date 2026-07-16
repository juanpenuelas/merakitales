import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String nameEs;
  final String nameEn;
  final String emoji;
  final String slug;
  final int sortOrder;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.emoji,
    required this.slug,
    required this.sortOrder,
    this.createdAt,
  });

  factory Category.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Category(
      id: doc.id,
      nameEs: d['name_es'] as String? ?? '',
      nameEn: d['name_en'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '',
      slug: d['slug'] as String? ?? '',
      sortOrder: d['sort_order'] as int? ?? 0,
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}
