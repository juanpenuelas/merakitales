import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/models/published_tale.dart';
import 'package:merakitales/admin/services/drafts_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late DraftsService service;

  Future<void> seedTale(int taleId, String lang, {String? categoryId}) async {
    await db.collection('tales').add({
      'tale_id': taleId,
      'lang': lang,
      'name': 'Cuento $taleId $lang',
      'is_premium_tale': true,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  Future<String?> categoryOf(int taleId, String lang) async {
    final q = await db
        .collection('tales')
        .where('tale_id', isEqualTo: taleId)
        .where('lang', isEqualTo: lang)
        .get();
    return q.docs.first.data()['category_id'] as String?;
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = DraftsService(db: db);
  });

  test('asignar categoria actualiza los docs ES y EN', () async {
    await seedTale(7, 'es');
    await seedTale(7, 'en');

    await service.updatePublishedTaleCategory(taleId: 7, categoryId: 'piratas');

    expect(await categoryOf(7, 'es'), 'piratas');
    expect(await categoryOf(7, 'en'), 'piratas');
  });

  test('asignar null limpia la categoria en ambos docs', () async {
    await seedTale(8, 'es', categoryId: 'piratas');
    await seedTale(8, 'en', categoryId: 'piratas');

    await service.updatePublishedTaleCategory(taleId: 8, categoryId: null);

    expect(await categoryOf(8, 'es'), isNull);
    expect(await categoryOf(8, 'en'), isNull);
  });

  test('con un solo doc existente actualiza ese y no lanza', () async {
    await seedTale(9, 'es');

    await service.updatePublishedTaleCategory(taleId: 9, categoryId: 'humor');

    expect(await categoryOf(9, 'es'), 'humor');
  });

  test('PublishedTale.fromDoc parsea category_id y tolera su ausencia',
      () async {
    await seedTale(10, 'es', categoryId: 'humor');
    await seedTale(11, 'es');
    final docs = await db
        .collection('tales')
        .where('lang', isEqualTo: 'es')
        .get();
    final tales = docs.docs.map(PublishedTale.fromDoc).toList();

    expect(tales.firstWhere((t) => t.taleId == 10).categoryId, 'humor');
    expect(tales.firstWhere((t) => t.taleId == 11).categoryId, isNull);
  });
}
