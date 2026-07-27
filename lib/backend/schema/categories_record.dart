import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CategoriesRecord extends FirestoreRecord {
  CategoriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name_es" field.
  String? _nameEs;
  String get nameEs => _nameEs ?? '';
  bool hasNameEs() => _nameEs != null;

  // "name_en" field.
  String? _nameEn;
  String get nameEn => _nameEn ?? '';
  bool hasNameEn() => _nameEn != null;

  // "emoji" field.
  String? _emoji;
  String get emoji => _emoji ?? '';
  bool hasEmoji() => _emoji != null;

  // "slug" field.
  String? _slug;
  String get slug => _slug ?? '';
  bool hasSlug() => _slug != null;

  // "sort_order" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  bool hasSortOrder() => _sortOrder != null;

  void _initializeFields() {
    _nameEs = snapshotData['name_es'] as String?;
    _nameEn = snapshotData['name_en'] as String?;
    _emoji = snapshotData['emoji'] as String?;
    _slug = snapshotData['slug'] as String?;
    _sortOrder = castToType<int>(snapshotData['sort_order']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('categories');

  static Stream<CategoriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CategoriesRecord.fromSnapshot(s));

  static Future<CategoriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CategoriesRecord.fromSnapshot(s));

  static CategoriesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CategoriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CategoriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CategoriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CategoriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CategoriesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCategoriesRecordData({
  String? nameEs,
  String? nameEn,
  String? emoji,
  String? slug,
  int? sortOrder,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name_es': nameEs,
      'name_en': nameEn,
      'emoji': emoji,
      'slug': slug,
      'sort_order': sortOrder,
    }.withoutNulls,
  );

  return firestoreData;
}

class CategoriesRecordDocumentEquality implements Equality<CategoriesRecord> {
  const CategoriesRecordDocumentEquality();

  @override
  bool equals(CategoriesRecord? e1, CategoriesRecord? e2) {
    return e1?.nameEs == e2?.nameEs &&
        e1?.nameEn == e2?.nameEn &&
        e1?.emoji == e2?.emoji &&
        e1?.slug == e2?.slug &&
        e1?.sortOrder == e2?.sortOrder;
  }

  @override
  int hash(CategoriesRecord? e) => const ListEquality()
      .hash([e?.nameEs, e?.nameEn, e?.emoji, e?.slug, e?.sortOrder]);

  @override
  bool isValidKey(Object? o) => o is CategoriesRecord;
}
