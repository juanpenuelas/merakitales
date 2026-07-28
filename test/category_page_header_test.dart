import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
