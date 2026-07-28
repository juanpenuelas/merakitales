import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/backend/backend.dart';
import 'package:merakitales/components/tale_cover_card.dart';

Future<TalesRecord> makeTale({DateTime? createdAt}) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('tales').doc('t1');
  await ref.set({
    'name': 'El dragon dormilon',
    'lang': 'es',
    'tale_id': 1,
    'is_premium_tale': true,
    'image_url_640px': 'https://example.com/x.png',
    if (createdAt != null) 'created_at': createdAt,
  });
  return TalesRecord.fromSnapshot(await ref.get());
}

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('muestra candado cuando locked y el titulo del cuento',
      (tester) async {
    final tale = await makeTale();
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: tale,
      locked: true,
      size: 120,
      onTap: () {},
    )));
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('El dragon dormilon'), findsOneWidget);
  });

  testWidgets('sin candado cuando locked es false', (tester) async {
    final tale = await makeTale();
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: tale,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('badge NUEVO solo con created_at reciente', (tester) async {
    final nuevo = await makeTale(createdAt: DateTime.now());
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: nuevo,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.text('NEW'), findsOneWidget); // MaterialApp de test va en 'en'

    final viejo =
        await makeTale(createdAt: DateTime.now().subtract(const Duration(days: 30)));
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: viejo,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.text('NEW'), findsNothing);
  });
}
