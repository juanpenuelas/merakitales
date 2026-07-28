import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/backend/backend.dart';
import 'package:merakitales/pages/category_page/category_page_widget.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockPremiumProvider extends ChangeNotifier implements PremiumProvider {
  @override
  bool isPremium = true; // premium: el banner de ads se auto-oculta y no toca plugins

  @override
  bool get isLoadingOfferings => false;
  @override
  Offerings? get offerings => null;
  @override
  CustomerInfo? get customerInfo => null;
  @override
  Future<void> init() async {}
  @override
  Future<void> loadOfferings() async {}
  @override
  Future<bool> purchasePackage(Package package) async => false;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  Future<void> updatePremiumStatus(bool isPremiumStatus) async {}
}

Widget wrap(Widget child) => ChangeNotifierProvider<PremiumProvider>.value(
      value: MockPremiumProvider(),
      child: MaterialApp(home: child),
    );

Future<TalesRecord> makeTale() async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('tales').doc('t1');
  await ref.set({
    'name': 'El dragon dormilon',
    'lang': 'es',
    'tale_id': 1,
    'is_premium_tale': true,
    'image_url_640px': 'https://example.com/x.png',
  });
  return TalesRecord.fromSnapshot(await ref.get());
}

void main() {
  testWidgets('cabecera con descripcion: "N tales · descripcion"',
      (tester) async {
    await tester.pumpWidget(wrap(const CategoryPageWidget(
      title: 'Mar y piratas',
      emoji: '🏴‍☠️',
      tales: [],
      description: 'Aventuras acuáticas',
    )));
    expect(find.text('0 tales · Aventuras acuáticas'), findsOneWidget);
  });

  testWidgets('cabecera sin descripcion: solo "N tales"', (tester) async {
    await tester.pumpWidget(wrap(const CategoryPageWidget(
      title: 'Mar y piratas',
      emoji: '🏴‍☠️',
      tales: [],
    )));
    expect(find.text('0 tales'), findsOneWidget);
  });

  testWidgets('cabecera singular: "1 tale" con un solo cuento',
      (tester) async {
    final tale = await makeTale();
    await tester.pumpWidget(wrap(CategoryPageWidget(
      title: 'Mar y piratas',
      emoji: '🏴‍☠️',
      tales: [tale],
    )));
    expect(find.textContaining('1 tale'), findsOneWidget);
    expect(find.textContaining('1 tales'), findsNothing);
  });
}
