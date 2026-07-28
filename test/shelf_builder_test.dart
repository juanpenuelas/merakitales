import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/backend/backend.dart';
import 'package:merakitales/services/shelf_builder.dart';

Future<TalesRecord> makeTale(
  FakeFirebaseFirestore db, {
  required int id,
  bool premium = false,
  String? categoryId,
}) async {
  final ref = db.collection('tales').doc('tale_$id');
  await ref.set({
    'name': 'Cuento $id',
    'lang': 'es',
    'tale_id': id,
    'is_premium_tale': premium,
    if (categoryId != null) 'category_id': categoryId,
  });
  return TalesRecord.fromSnapshot(await ref.get());
}

Future<CategoriesRecord> makeCategory(
  FakeFirebaseFirestore db, {
  required String id,
  required int sortOrder,
}) async {
  final ref = db.collection('categories').doc(id);
  await ref.set({
    'name_es': 'Cat $id',
    'name_en': 'Cat $id EN',
    'emoji': '⭐',
    'slug': id,
    'sort_order': sortOrder,
  });
  return CategoriesRecord.fromSnapshot(await ref.get());
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  test('usuario gratuito: novedades, gratis y categorias por sort_order',
      () async {
    final catA = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final catB = await makeCategory(db, id: 'humor', sortOrder: 2);
    final tales = [
      await makeTale(db, id: 5, premium: true, categoryId: 'humor'),
      await makeTale(db, id: 4, premium: true, categoryId: 'aventuras'),
      await makeTale(db, id: 3),
      await makeTale(db, id: 2),
      await makeTale(db, id: 1),
    ];

    final shelves = buildShelves(
        tales: tales, categories: [catA, catB], isPremiumUser: false);

    expect(shelves.map((s) => s.type).toList(), [
      ShelfType.novedades,
      ShelfType.gratis,
      ShelfType.categoria,
      ShelfType.categoria,
    ]);
    expect(shelves[1].tales.map((t) => t.taleId), [3, 2, 1]);
    expect(shelves[2].category!.reference.id, 'aventuras');
    expect(shelves[2].tales.single.taleId, 4);
    expect(shelves[3].category!.reference.id, 'humor');
  });

  test('usuario premium: gratis va al final', () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 2, premium: true, categoryId: 'aventuras'),
      await makeTale(db, id: 1),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: true);

    expect(shelves.map((s) => s.type).toList(), [
      ShelfType.novedades,
      ShelfType.categoria,
      ShelfType.gratis,
    ]);
  });

  test('novedades se limita a 10 y conserva el orden de entrada', () async {
    final tales = [
      for (var id = 15; id >= 1; id--) await makeTale(db, id: id),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [], isPremiumUser: false);

    final novedades = shelves.firstWhere((s) => s.type == ShelfType.novedades);
    expect(novedades.tales.length, 10);
    expect(novedades.tales.first.taleId, 15);
    expect(novedades.tales.last.taleId, 6);
  });

  test('categoria sin cuentos no aparece', () async {
    final vacia = await makeCategory(db, id: 'vacia', sortOrder: 1);
    final tales = [await makeTale(db, id: 1)];

    final shelves =
        buildShelves(tales: tales, categories: [vacia], isPremiumUser: false);

    expect(shelves.where((s) => s.type == ShelfType.categoria), isEmpty);
  });

  test('cuento premium con category_id desconocido solo sale en novedades',
      () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 2, premium: true, categoryId: 'borrada'),
      await makeTale(db, id: 1, premium: true, categoryId: 'aventuras'),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: false);

    final categoria = shelves.where((s) => s.type == ShelfType.categoria);
    expect(categoria.single.tales.single.taleId, 1);
    final novedades = shelves.firstWhere((s) => s.type == ShelfType.novedades);
    expect(novedades.tales.map((t) => t.taleId), [2, 1]);
  });

  test('catalogo vacio devuelve cero estanterias', () async {
    final shelves =
        buildShelves(tales: [], categories: [], isPremiumUser: false);
    expect(shelves, isEmpty);
  });

  test('sin cuentos gratis no hay estanteria gratis', () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 1, premium: true, categoryId: 'aventuras'),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: false);

    expect(shelves.where((s) => s.type == ShelfType.gratis), isEmpty);
  });
}
