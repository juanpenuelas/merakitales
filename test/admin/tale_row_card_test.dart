import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/widgets/tale_row_card.dart';
import 'package:merakitales/admin/widgets/status_badge.dart';

void main() {
  testWidgets('renders title and badges', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TaleRowCard(
      title: 'El bosque',
      imageUrl640: '',
      badges: [StatusBadge.published()],
      placeholder: Icons.public,
    ))));
    expect(find.text('El bosque'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
  });
}
