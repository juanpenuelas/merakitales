import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:merakitales/components/premium_badge_widget.dart';
import 'package:merakitales/pages/subscription_page/subscription_page_widget.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockPremiumProvider extends ChangeNotifier implements PremiumProvider {
  @override
  bool isPremium = false;

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

void main() {
  testWidgets('PremiumBadgeWidget unconditionally navigates to SubscriptionPageWidget when tapped (Premium: false)', (WidgetTester tester) async {
    final mockProvider = MockPremiumProvider();
    mockProvider.isPremium = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumProvider>.value(
        value: mockProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumBadgeWidget(),
          ),
        ),
      ),
    );

    // The badge should always be visible.
    final badgeFinder = find.byType(PremiumBadgeWidget);
    expect(badgeFinder, findsOneWidget);

    // Tap it
    await tester.tap(badgeFinder);
    await tester.pumpAndSettle();

    // Verify it navigated to SubscriptionPageWidget
    expect(find.byType(SubscriptionPageWidget), findsOneWidget);
  });
  
  testWidgets('PremiumBadgeWidget unconditionally navigates to SubscriptionPageWidget when tapped (Premium: true)', (WidgetTester tester) async {
    final mockProvider = MockPremiumProvider();
    mockProvider.isPremium = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumProvider>.value(
        value: mockProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumBadgeWidget(),
          ),
        ),
      ),
    );

    // The badge should always be visible.
    final badgeFinder = find.byType(PremiumBadgeWidget);
    expect(badgeFinder, findsOneWidget);

    // Tap it
    await tester.tap(badgeFinder);
    await tester.pumpAndSettle();

    // Verify it navigated to SubscriptionPageWidget
    expect(find.byType(SubscriptionPageWidget), findsOneWidget);
  });
}
