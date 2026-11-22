import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/article_draft.dart';
import '../models/json_compat.dart';

typedef SyncedDraft = ({ArticleDraft? draft, int revision});

class FirestoreDraftStore {
  FirestoreDraftStore(FirebaseFirestore firestore, {required String uid})
    : _drafts = firestore.collection('users').doc(uid).collection('drafts');

  final CollectionReference<Map<String, dynamic>> _drafts;

  Stream<SyncedDraft> watchDraft(String id) {
    final document = _drafts.doc(requireUuid(id, 'id'));
    return document.snapshots().map((snapshot) {
      final data = snapshot.data();
      final revision = data?['revision'] as int? ?? 0;
      final payload = data?['payload'] as Map<String, dynamic>?;
      if (payload == null || data?['deleted'] == true) {
        return (draft: null, revision: revision);
      }
      return (
        draft: ArticleDraft.fromJson({
          // Earlier emulator builds stored only the title.
          'articleType': '日記',
          ...payload,
          'id': document.id,
        }),
        revision: revision,
      );
    });
  }

  Future<bool> saveDraft(ArticleDraft draft, {required int expectedRevision}) {
    final document = _drafts.doc(requireUuid(draft.id, 'id'));
    final payload = draft.toJson();
    return _drafts.firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      final revision = existing.data()?['revision'] as int? ?? 0;
      if (revision != expectedRevision) return false;
      transaction.set(document, {
        'revision': revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': false,
        'payload': payload,
      });
      return true;
    });
  }
}
