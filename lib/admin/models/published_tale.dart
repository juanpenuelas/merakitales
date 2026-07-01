import 'package:cloud_firestore/cloud_firestore.dart';

class PublishedTale {
  final String id;
  final int taleId;
  final String lang;
  final String name;
  final String description;
  final String imageUrl;
  final String imageUrl640;
  final DateTime? createdAt;

  PublishedTale({
    required this.id,
    required this.taleId,
    required this.lang,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.imageUrl640,
    this.createdAt,
  });

  factory PublishedTale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PublishedTale(
      id: doc.id,
      taleId: d['tale_id'] as int? ?? 0,
      lang: d['lang'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      imageUrl: d['image_url'] as String? ?? '',
      imageUrl640: d['image_url_640px'] as String? ?? '',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}
