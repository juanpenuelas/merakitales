import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/widgets/status_badge.dart';

void main() {
  testWidgets('new badge factories render their labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          StatusBadge.scheduled(),
          StatusBadge.published(),
          StatusBadge.category('Aventuras'),
        ]),
      ),
    ));
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Aventuras'), findsOneWidget);
  });
}
