import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TalesCommonDataRecord extends FirestoreRecord {
  TalesCommonDataRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "tale_id" field.
  int? _taleId;
  int get taleId => _taleId ?? 0;
  bool hasTaleId() => _taleId != null;

  // "image_url_1024px" field.
  String? _imageUrl1024px;
  String get imageUrl1024px => _imageUrl1024px ?? '';
  bool hasImageUrl1024px() => _imageUrl1024px != null;

  // "image_url_640px" field.
  String? _imageUrl640px;
  String get imageUrl640px => _imageUrl640px ?? '';
  bool hasImageUrl640px() => _imageUrl640px != null;

  void _initializeFields() {
    _taleId = castToType<int>(snapshotData['tale_id']);
    _imageUrl1024px = snapshotData['image_url_1024px'] as String?;
    _imageUrl640px = snapshotData['image_url_640px'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('tales_common_data');

  static Stream<TalesCommonDataRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TalesCommonDataRecord.fromSnapshot(s));

  static Future<TalesCommonDataRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TalesCommonDataRecord.fromSnapshot(s));

  static TalesCommonDataRecord fromSnapshot(DocumentSnapshot snapshot) =>
      TalesCommonDataRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TalesCommonDataRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TalesCommonDataRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TalesCommonDataRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TalesCommonDataRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTalesCommonDataRecordData({
  int? taleId,
  String? imageUrl1024px,
  String? imageUrl640px,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'tale_id': taleId,
      'image_url_1024px': imageUrl1024px,
      'image_url_640px': imageUrl640px,
    }.withoutNulls,
  );

  return firestoreData;
}

class TalesCommonDataRecordDocumentEquality
    implements Equality<TalesCommonDataRecord> {
  const TalesCommonDataRecordDocumentEquality();

  @override
  bool equals(TalesCommonDataRecord? e1, TalesCommonDataRecord? e2) {
    return e1?.taleId == e2?.taleId &&
        e1?.imageUrl1024px == e2?.imageUrl1024px &&
        e1?.imageUrl640px == e2?.imageUrl640px;
  }

  @override
  int hash(TalesCommonDataRecord? e) => const ListEquality()
      .hash([e?.taleId, e?.imageUrl1024px, e?.imageUrl640px]);

  @override
  bool isValidKey(Object? o) => o is TalesCommonDataRecord;
}
