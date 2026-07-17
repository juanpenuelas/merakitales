import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/draft.dart';
import '../models/published_tale.dart';

class DraftsService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Stream<List<Draft>> streamDraftsByStatuses(List<String> statuses) {
    return _db
        .collection('tale_drafts')
        .where('status', whereIn: statuses)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Draft.fromDoc).toList());
  }

  Stream<List<Draft>> streamDrafts() => streamDraftsByStatuses(['pending']);

  Stream<Draft?> streamDraft(String id) {
    return _db.collection('tale_drafts').doc(id).snapshots().map((s) => s.exists ? Draft.fromDoc(s) : null);
  }

  /// Stream of published tales (ES only to avoid duplicates, ordered by tale_id desc)
  Stream<List<PublishedTale>> streamPublished() {
    return _db
        .collection('tales')
        .where('lang', isEqualTo: 'es')
        .orderBy('tale_id', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(PublishedTale.fromDoc).toList());
  }

  /// Loads the full bilingual content (ES + EN) for one published tale.
  /// Looks up by `tale_id`+`lang` fields rather than the doc id: every
  /// published tale (old and new) has a Firestore auto-generated doc id,
  /// never a predictable one, so nothing may ever look it up by guessing.
  Future<PublishedTaleFull> getPublishedTale(int taleId) async {
    Future<Map<String, dynamic>?> fetchByLang(String lang) async {
      final q = await _db
          .collection('tales')
          .where('tale_id', isEqualTo: taleId)
          .where('lang', isEqualTo: lang)
          .limit(1)
          .get();
      return q.docs.isEmpty ? null : q.docs.first.data();
    }

    final snaps = await Future.wait([fetchByLang('es'), fetchByLang('en')]);
    return PublishedTaleFull.fromDocs(
      taleId: taleId,
      esData: snaps[0],
      enData: snaps[1],
    );
  }

  Future<String> createManualDraft({
    required String nameEs,
    required String descriptionEs,
    required String specificationsEs,
    required String nameEn,
    required String descriptionEn,
    required String specificationsEn,
  }) async {
    final ref = _db.collection('tale_drafts').doc();
    await ref.set({
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'decided_at': null,
      'decided_by': null,
      'name_es': nameEs,
      'description_es': descriptionEs,
      'specifications_es': specificationsEs,
      'audio_url_es': '',
      'image_prompt': '',
      'name_en': nameEn,
      'description_en': descriptionEn,
      'specifications_en': specificationsEn,
      'audio_url_en': '',
      'image_url': '',
      'image_url_640px': '',
      'assigned_tale_id': null,
      'retracted_from_tale_id': null,
      'is_premium_tale': false,
      'category_id': null,
    });
    return ref.id;
  }

  Future<void> updateManualDraftText({
    required String draftId,
    required String nameEs,
    required String descriptionEs,
    required String specificationsEs,
    required String nameEn,
    required String descriptionEn,
    required String specificationsEn,
  }) async {
    await _db.collection('tale_drafts').doc(draftId).update({
      'name_es': nameEs,
      'description_es': descriptionEs,
      'specifications_es': specificationsEs,
      'name_en': nameEn,
      'description_en': descriptionEn,
      'specifications_en': specificationsEn,
    });
  }

  Future<void> updateDraftPremium({required String draftId, required bool isPremiumTale}) async {
    await _db.collection('tale_drafts').doc(draftId).update({'is_premium_tale': isPremiumTale});
  }

  UploadTask uploadDraftImage(String draftId, Uint8List bytes) {
    final ref = FirebaseStorage.instance.ref('drafts/$draftId/image_1024.png');
    return ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
  }

  Future<void> resizeDraftImage(String draftId) async {
    await _functions.httpsCallable('resizeDraftImage').call({'draftId': draftId});
  }

  UploadTask uploadDraftAudio(String draftId, String lang, Uint8List bytes) {
    final ref = FirebaseStorage.instance.ref('drafts/$draftId/audio_$lang.mp3');
    return ref.putData(bytes, SettableMetadata(contentType: 'audio/mpeg'));
  }

  Future<void> saveManualDraftAudioUrl({
    required String draftId,
    required String lang,
    required String url,
  }) async {
    await _db.collection('tale_drafts').doc(draftId).update({'audio_url_$lang': url});
  }

  Future<void> updateDraftText(String draftId, String lang, String text) async {
    await _functions.httpsCallable('updateDraftText').call({
      'draftId': draftId,
      'lang': lang,
      'text': text,
    });
  }

  Future<String> generateText({String? theme, String? feedback}) async {
    final result = await _functions.httpsCallable('generateTaleText').call({
      'theme': theme,
      'feedback': feedback,
    });
    return result.data['draftId'] as String;
  }

  Future<void> generateImage(String draftId, {String? feedback}) async {
    await _functions.httpsCallable('generateTaleImage').call({
      'draftId': draftId,
      'feedback': feedback,
    });
  }

  Future<void> generateAudio(String draftId, String lang, {String? feedback}) async {
    await _functions.httpsCallable('generateTaleAudio').call({
      'draftId': draftId,
      'lang': lang,
      'feedback': feedback,
    });
  }

  Future<int> approveDraft(String id) async {
    final result = await _functions.httpsCallable('approveDraft').call({'draftId': id});
    return result.data['taleId'] as int;
  }

  Future<void> rejectDraft(String id) async {
    await _functions.httpsCallable('rejectDraft').call({'draftId': id});
  }

  Future<void> scheduleDraft(String draftId, DateTime scheduledAt) async {
    await _functions.httpsCallable('scheduleDraft').call({
      'draftId': draftId,
      'scheduledAtISO': scheduledAt.toUtc().toIso8601String(),
    });
  }

  /// Cancel a schedule. Backend has no dedicated endpoint; the admin uid is
  /// allowed to write tale_drafts, so revert the doc directly.
  Future<void> cancelSchedule(String draftId) async {
    await _db.collection('tale_drafts').doc(draftId).update({
      'status': 'pending',
      'scheduled_at': FieldValue.delete(),
      'scheduled_by': FieldValue.delete(),
    });
  }

  Future<void> updateDraftCategory({required String draftId, required String? categoryId}) async {
    await _db.collection('tale_drafts').doc(draftId).update({'category_id': categoryId});
  }

  Future<String> retractTale(int taleId) async {
    final result = await _functions.httpsCallable('retractTale').call({'taleId': taleId});
    return result.data['draftId'] as String;
  }
}
