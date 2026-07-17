import 'package:cloud_firestore/cloud_firestore.dart';

class PublishedTale {
  final String id;
  final int taleId;
  final String lang;
  final String name;
  final String description;
  final String imageUrl;
  final String imageUrl640;
  final bool isPremiumTale;
  final DateTime? createdAt;

  PublishedTale({
    required this.id,
    required this.taleId,
    required this.lang,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.imageUrl640,
    this.isPremiumTale = false,
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
      isPremiumTale: d['is_premium_tale'] as bool? ?? false,
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Full bilingual content for a published tale, used by the detail page.
class PublishedTaleFull {
  final int taleId;
  final String nameEs;
  final String descriptionEs;
  final String specificationsEs;
  final String audioUrlEs;
  final String nameEn;
  final String descriptionEn;
  final String specificationsEn;
  final String audioUrlEn;
  final String imageUrl;
  final String imageUrl640;

  PublishedTaleFull({
    required this.taleId,
    required this.nameEs,
    required this.descriptionEs,
    required this.specificationsEs,
    required this.audioUrlEs,
    required this.nameEn,
    required this.descriptionEn,
    required this.specificationsEn,
    required this.audioUrlEn,
    required this.imageUrl,
    required this.imageUrl640,
  });

  factory PublishedTaleFull.fromDocs({
    required int taleId,
    required Map<String, dynamic>? esData,
    required Map<String, dynamic>? enData,
  }) {
    final es = esData ?? {};
    final en = enData ?? {};
    return PublishedTaleFull(
      taleId: taleId,
      nameEs: es['name'] as String? ?? '',
      descriptionEs: es['description'] as String? ?? '',
      specificationsEs: es['specifications'] as String? ?? '',
      audioUrlEs: es['audio_url'] as String? ?? '',
      nameEn: en['name'] as String? ?? '',
      descriptionEn: en['description'] as String? ?? '',
      specificationsEn: en['specifications'] as String? ?? '',
      audioUrlEn: en['audio_url'] as String? ?? '',
      imageUrl: es['image_url'] as String? ?? en['image_url'] as String? ?? '',
      imageUrl640: es['image_url_640px'] as String? ?? en['image_url_640px'] as String? ?? '',
    );
  }
}

