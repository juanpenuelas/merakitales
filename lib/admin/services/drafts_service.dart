import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/draft.dart';
import '../models/published_tale.dart';

class DraftsService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Stream<List<Draft>> streamDrafts() {
    return _db
        .collection('tale_drafts')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Draft.fromDoc).toList());
  }

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

  Future<String> retractTale(int taleId) async {
    final result = await _functions.httpsCallable('retractTale').call({'taleId': taleId});
    return result.data['draftId'] as String;
  }
}
