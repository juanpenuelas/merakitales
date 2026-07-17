import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/categories/category_editor_dialog.dart';

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
    await tester.tap(find.byKey(const Key('cat_save')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.nameEs, 'Aventuras');
    expect(result!.slug, 'aventuras');
  });
}
