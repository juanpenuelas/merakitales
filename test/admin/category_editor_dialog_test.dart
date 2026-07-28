import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/categories/category_editor_dialog.dart';
import 'package:merakitales/admin/models/category.dart';

void main() {
  testWidgets('save returns entered values with auto slug', (tester) async {
    CategoryFormResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () async { result = await showCategoryEditor(ctx); },
        child: const Text('open'),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cat_name_es')), 'Aventuras');
    await tester.enterText(find.byKey(const Key('cat_name_en')), 'Adventures');
    await tester.enterText(find.byKey(const Key('cat_emoji')), '🗺️');
    await tester.enterText(find.byKey(const Key('cat_desc_es')), 'Aventuras y mapas');
    await tester.enterText(find.byKey(const Key('cat_desc_en')), 'Adventures and maps');
    await tester.tap(find.byKey(const Key('cat_save')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.nameEs, 'Aventuras');
    expect(result!.slug, 'aventuras');
    expect(result!.descriptionEs, 'Aventuras y mapas');
    expect(result!.descriptionEn, 'Adventures and maps');
  });

  test('Category.fromDoc parsea descripciones y tolera su ausencia', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('categories').doc('con').set({
      'name_es': 'Mar',
      'name_en': 'Sea',
      'emoji': '🌊',
      'slug': 'mar',
      'sort_order': 1,
      'description_es': 'Aventuras acuáticas',
      'description_en': 'Water adventures',
    });
    await db.collection('categories').doc('sin').set({
      'name_es': 'Humor',
      'name_en': 'Humor',
      'emoji': '😂',
      'slug': 'humor',
      'sort_order': 2,
    });

    final con = Category.fromDoc(await db.collection('categories').doc('con').get());
    final sin = Category.fromDoc(await db.collection('categories').doc('sin').get());

    expect(con.descriptionEs, 'Aventuras acuáticas');
    expect(con.descriptionEn, 'Water adventures');
    expect(sin.descriptionEs, '');
    expect(sin.descriptionEn, '');
  });
}
