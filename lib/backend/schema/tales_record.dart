import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TalesRecord extends FirestoreRecord {
  TalesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "specifications" field.
  String? _specifications;
  String get specifications => _specifications ?? '';
  bool hasSpecifications() => _specifications != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "modified_at" field.
  DateTime? _modifiedAt;
  DateTime? get modifiedAt => _modifiedAt;
  bool hasModifiedAt() => _modifiedAt != null;

  // "on_sale" field.
  bool? _onSale;
  bool get onSale => _onSale ?? false;
  bool hasOnSale() => _onSale != null;

  // "sale_price" field.
  double? _salePrice;
  double get salePrice => _salePrice ?? 0.0;
  bool hasSalePrice() => _salePrice != null;

  // "quantity" field.
  int? _quantity;
  int get quantity => _quantity ?? 0;
  bool hasQuantity() => _quantity != null;

  // "image_url" field.
  String? _imageUrl;
  String get imageUrl => _imageUrl ?? '';
  bool hasImageUrl() => _imageUrl != null;

  // "lang" field.
  String? _lang;
  String get lang => _lang ?? '';
  bool hasLang() => _lang != null;

  // "tale_id" field.
  int? _taleId;
  int get taleId => _taleId ?? 0;
  bool hasTaleId() => _taleId != null;

  // "image_url_640px" field.
  String? _imageUrl640px;
  String get imageUrl640px => _imageUrl640px ?? '';
  bool hasImageUrl640px() => _imageUrl640px != null;

  // "tale_common_data_ref" field.
  DocumentReference? _taleCommonDataRef;
  DocumentReference? get taleCommonDataRef => _taleCommonDataRef;
  bool hasTaleCommonDataRef() => _taleCommonDataRef != null;

  // "audio_url" field.
  String? _audioUrl;
  String get audioUrl => _audioUrl ?? '';
  bool hasAudioUrl() => _audioUrl != null;

  // "is_premium_tale" field.
  bool? _isPremiumTale;
  bool get isPremiumTale => _isPremiumTale ?? false;
  bool hasIsPremiumTale() => _isPremiumTale != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _description = snapshotData['description'] as String?;
    _specifications = snapshotData['specifications'] as String?;
    _price = castToType<double>(snapshotData['price']);
    _createdAt = snapshotData['created_at'] as DateTime?;
    _modifiedAt = snapshotData['modified_at'] as DateTime?;
    _onSale = snapshotData['on_sale'] as bool?;
    _salePrice = castToType<double>(snapshotData['sale_price']);
    _quantity = castToType<int>(snapshotData['quantity']);
    _imageUrl = snapshotData['image_url'] as String?;
    _lang = snapshotData['lang'] as String?;
    _taleId = castToType<int>(snapshotData['tale_id']);
    _imageUrl640px = snapshotData['image_url_640px'] as String?;
    _taleCommonDataRef =
        snapshotData['tale_common_data_ref'] as DocumentReference?;
    _audioUrl = snapshotData['audio_url'] as String?;
    _isPremiumTale = snapshotData['is_premium_tale'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('tales');

  static Stream<TalesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TalesRecord.fromSnapshot(s));

  static Future<TalesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TalesRecord.fromSnapshot(s));

  static TalesRecord fromSnapshot(DocumentSnapshot snapshot) => TalesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TalesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TalesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TalesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TalesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTalesRecordData({
  String? name,
  String? description,
  String? specifications,
  double? price,
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool? onSale,
  double? salePrice,
  int? quantity,
  String? imageUrl,
  String? lang,
  int? taleId,
  String? imageUrl640px,
  DocumentReference? taleCommonDataRef,
  String? audioUrl,
  bool? isPremiumTale,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'description': description,
      'specifications': specifications,
      'price': price,
      'created_at': createdAt,
      'modified_at': modifiedAt,
      'on_sale': onSale,
      'sale_price': salePrice,
      'quantity': quantity,
      'image_url': imageUrl,
      'lang': lang,
      'tale_id': taleId,
      'image_url_640px': imageUrl640px,
      'tale_common_data_ref': taleCommonDataRef,
      'audio_url': audioUrl,
      'is_premium_tale': isPremiumTale,
    }.withoutNulls,
  );

  return firestoreData;
}

class TalesRecordDocumentEquality implements Equality<TalesRecord> {
  const TalesRecordDocumentEquality();

  @override
  bool equals(TalesRecord? e1, TalesRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.description == e2?.description &&
        e1?.specifications == e2?.specifications &&
        e1?.price == e2?.price &&
        e1?.createdAt == e2?.createdAt &&
        e1?.modifiedAt == e2?.modifiedAt &&
        e1?.onSale == e2?.onSale &&
        e1?.salePrice == e2?.salePrice &&
        e1?.quantity == e2?.quantity &&
        e1?.imageUrl == e2?.imageUrl &&
        e1?.lang == e2?.lang &&
        e1?.taleId == e2?.taleId &&
        e1?.imageUrl640px == e2?.imageUrl640px &&
        e1?.taleCommonDataRef == e2?.taleCommonDataRef &&
        e1?.audioUrl == e2?.audioUrl &&
        e1?.isPremiumTale == e2?.isPremiumTale;
  }

  @override
  int hash(TalesRecord? e) => const ListEquality().hash([
        e?.name,
        e?.description,
        e?.specifications,
        e?.price,
        e?.createdAt,
        e?.modifiedAt,
        e?.onSale,
        e?.salePrice,
        e?.quantity,
        e?.imageUrl,
        e?.lang,
        e?.taleId,
        e?.imageUrl640px,
        e?.taleCommonDataRef,
        e?.audioUrl,
        e?.isPremiumTale
      ]);

  @override
  bool isValidKey(Object? o) => o is TalesRecord;
}
