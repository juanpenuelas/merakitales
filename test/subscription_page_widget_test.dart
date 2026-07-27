import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:merakitales/pages/subscription_page/subscription_page_widget.dart';
import 'package:merakitales/pages/paywall_widget.dart';
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

  testWidgets('sends non-premium users to the paywall, not the status page', (WidgetTester tester) async {
    final provider = FakePremiumProvider(isPremium: false);
    await tester.pumpWidget(createWidgetUnderTest(provider));

    // El paywall es la unica pantalla con precio y boton de compra; la pagina
    // de estado no tiene camino a la compra, asi que no-premium no debe verla.
    expect(find.byType(PaywallWidget), findsOneWidget);
    expect(find.byType(SubscriptionHeroCardWidget), findsNothing);
    expect(find.text('Gestionar suscripción'), findsNothing);
  });

  testWidgets('a premium flip mid-purchase must not swap the paywall away', (WidgetTester tester) async {
    // El paywall abre un diálogo de carga y lo cierra el mismo despues del
    // await. Si al activarse premium esta pagina lo desmonta, ese diálogo se
    // queda huerfano y el spinner gira para siempre: el paywall debe seguir
    // montado hasta que el se cierre solo.
    final provider = FakePremiumProvider(isPremium: false);
    await tester.pumpWidget(createWidgetUnderTest(provider));
    expect(find.byType(PaywallWidget), findsOneWidget);

    provider.update(true, null); // lo que hace purchasePackage al completarse
    await tester.pump();

    expect(find.byType(PaywallWidget), findsOneWidget);
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
