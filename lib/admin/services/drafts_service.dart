import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rxdart/rxdart.dart';

import '../models/draft.dart';

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

  Future<String> generateDraft({String? theme}) async {
    final result = await _functions.httpsCallable('generateTaleDraft').call({'theme': theme});
    return result.data['draftId'] as String;
  }

  Future<int> approveDraft(String id) async {
    final result = await _functions.httpsCallable('approveDraft').call({'draftId': id});
    return result.data['taleId'] as int;
  }

  Future<void> rejectDraft(String id) async {
    await _functions.httpsCallable('rejectDraft').call({'draftId': id});
  }
}
