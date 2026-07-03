import 'package:cloud_firestore/cloud_firestore.dart';

class Draft {
  final String id;
  final String status;
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
  final DateTime? scheduledAt;
  
  final bool isGeneratingText;
  final bool isGeneratingImage;
  final bool isGeneratingAudioEs;
  final bool isGeneratingAudioEn;

  Draft({
    required this.id,
    required this.status,
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
    this.scheduledAt,
    this.isGeneratingText = false,
    this.isGeneratingImage = false,
    this.isGeneratingAudioEs = false,
    this.isGeneratingAudioEn = false,
  });

  /// Derived purely from which assets exist for badges
  String get step {
    if (imageUrl.isNotEmpty && audioUrlEs.isNotEmpty && audioUrlEn.isNotEmpty) return 'audio';
    if (imageUrl.isNotEmpty) return 'image';
    return 'text';
  }

  bool get isReadyToPublish {
    return specificationsEs.trim().isNotEmpty &&
           specificationsEn.trim().isNotEmpty &&
           imageUrl.trim().isNotEmpty &&
           audioUrlEs.trim().isNotEmpty &&
           audioUrlEn.trim().isNotEmpty;
  }

  factory Draft.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Draft(
      id: doc.id,
      status: d['status'] as String? ?? 'pending',
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
      isGeneratingText: d['is_generating_text'] as bool? ?? false,
      isGeneratingImage: d['is_generating_image'] as bool? ?? false,
      isGeneratingAudioEs: d['is_generating_audio_es'] as bool? ?? false,
      isGeneratingAudioEn: d['is_generating_audio_en'] as bool? ?? false,
      scheduledAt: (d['scheduled_at'] as Timestamp?)?.toDate(),
    );
  }
}
