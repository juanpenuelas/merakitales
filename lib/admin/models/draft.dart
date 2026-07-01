import 'package:cloud_firestore/cloud_firestore.dart';

class Draft {
  final String id;
  final String status;
  final String step;
  final DateTime? createdAt;
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
  final String imagePrompt;
  final int? assignedTaleId;
  final int? retractedFromTaleId;

  Draft({
    required this.id,
    required this.status,
    required this.step,
    this.createdAt,
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
    required this.imagePrompt,
    this.assignedTaleId,
    this.retractedFromTaleId,
  });

  factory Draft.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Draft(
      id: doc.id,
      status: d['status'] as String? ?? 'pending',
      step: d['step'] as String? ?? 'text',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      nameEs: d['name_es'] as String? ?? '',
      descriptionEs: d['description_es'] as String? ?? '',
      specificationsEs: d['specifications_es'] as String? ?? '',
      audioUrlEs: d['audio_url_es'] as String? ?? '',
      nameEn: d['name_en'] as String? ?? '',
      descriptionEn: d['description_en'] as String? ?? '',
      specificationsEn: d['specifications_en'] as String? ?? '',
      audioUrlEn: d['audio_url_en'] as String? ?? '',
      imageUrl: d['image_url'] as String? ?? '',
      imageUrl640: d['image_url_640px'] as String? ?? '',
      imagePrompt: d['image_prompt'] as String? ?? '',
      assignedTaleId: d['assigned_tale_id'] as int?,
      retractedFromTaleId: d['retracted_from_tale_id'] as int?,
    );
  }
}
