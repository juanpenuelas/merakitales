import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:merakitales/pages/subscription_page/subscription_page_widget.dart';
import 'package:merakitales/components/subscription_hero_card_widget.dart';
import 'package:merakitales/components/subscription_benefits_list_widget.dart';
import 'package:merakitales/components/manage_subscription_bottom_sheet.dart';
import 'package:merakitales/services/subscription_service.dart';

class MockCustomerInfo extends Fake implements CustomerInfo {
  @override
  final String? latestExpirationDate;
  @override
  final String? managementURL;

  MockCustomerInfo({this.latestExpirationDate, this.managementURL});
}

class FakePremiumProvider extends ChangeNotifier implements PremiumProvider {
  @override
  bool isPremium;
  @override
  CustomerInfo? customerInfo;

  FakePremiumProvider({this.isPremium = false, this.customerInfo});

  @override
  Future<void> init() async {}
  @override
  Future<void> updatePremiumStatus(bool active) async {}
  @override
  Future<void> loadOfferings() async {}
  @override
  Future<bool> purchasePackage(Package package) async => false;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  bool get isLoadingOfferings => false;
  @override
  Offerings? get offerings => null;

  void update(bool isPremiumValue, CustomerInfo? info) {
    isPremium = isPremiumValue;
    customerInfo = info;
    notifyListeners();
  }
}

void main() {
  Widget createWidgetUnderTest(FakePremiumProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<PremiumProvider>.value(
        value: provider,
        child: const SubscriptionPageWidget(),
      ),
    );
  }

  testWidgets('renders free state correctly when isPremium is false', (WidgetTester tester) async {
    final provider = FakePremiumProvider(isPremium: false);
    await tester.pumpWidget(createWidgetUnderTest(provider));

    expect(find.byType(SubscriptionHeroCardWidget), findsOneWidget);
    expect(find.byType(SubscriptionBenefitsListWidget), findsOneWidget);
    expect(find.text('Gestionar suscripción'), findsNothing);
  });

  testWidgets('renders premium state correctly when isPremium is true', (WidgetTester tester) async {
    final customerInfo = MockCustomerInfo(
      latestExpirationDate: '2026-12-31T23:59:59Z',
      managementURL: 'https://manage.subscription.com',
    );
    final provider = FakePremiumProvider(isPremium: true, customerInfo: customerInfo);
    await tester.pumpWidget(createWidgetUnderTest(provider));

    expect(find.byType(SubscriptionHeroCardWidget), findsOneWidget);
    expect(find.byType(SubscriptionBenefitsListWidget), findsOneWidget);
    expect(find.text('Gestionar suscripción'), findsOneWidget);
  });

  testWidgets('tapping Gestionar suscripción opens ManageSubscriptionBottomSheet', (WidgetTester tester) async {
    final customerInfo = MockCustomerInfo(
      latestExpirationDate: '2026-12-31T23:59:59Z',
      managementURL: 'https://manage.subscription.com',
    );
    final provider = FakePremiumProvider(isPremium: true, customerInfo: customerInfo);
    await tester.pumpWidget(createWidgetUnderTest(provider));

    await tester.tap(find.text('Gestionar suscripción'));
    await tester.pumpAndSettle();

    expect(find.byType(ManageSubscriptionBottomSheet), findsOneWidget);
  });
}
