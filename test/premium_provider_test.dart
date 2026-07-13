import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:merakitales/services/revenuecat_config.dart';

class MockPurchasesWrapper implements PurchasesWrapper {
  final CustomerInfo initialCustomerInfo;
  final List<void Function(CustomerInfo)> listeners = [];
  String? configuredApiKey;
  LogLevel? configuredLogLevel;
  int configureCallCount = 0;
  bool throwOnGetCustomerInfo = false;
  bool throwOnConfigure = false;

  MockPurchasesWrapper({
    required this.initialCustomerInfo,
    this.throwOnGetCustomerInfo = false,
    this.throwOnConfigure = false,
  });

  @override
  Future<void> configure(String apiKey) async {
    if (throwOnConfigure) {
      throw Exception('Configuration failed');
    }
    configuredApiKey = apiKey;
    configureCallCount++;
  }

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    if (throwOnGetCustomerInfo) {
      throw Exception('Network error');
    }
    return initialCustomerInfo;
  }

  @override
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {
    listeners.add(listener);
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {
    configuredLogLevel = level;
  }

  void triggerUpdate(CustomerInfo customerInfo) {
    for (final listener in listeners) {
      listener(customerInfo);
    }
  }
}

CustomerInfo createMockCustomerInfo({required bool isPremium}) {
  final entitlement = EntitlementInfo(
    'premium', // identifier
    isPremium, // isActive
    true, // willRenew
    '2026-07-13T16:00:00Z', // latestPurchaseDate
    '2026-07-13T16:00:00Z', // originalPurchaseDate
    'premium_product', // productIdentifier
    true, // isSandbox
  );

  final entitlementInfos = EntitlementInfos(
    {'premium': entitlement}, // all
    isPremium ? {'premium': entitlement} : {}, // active
  );

  return CustomerInfo(
    entitlementInfos, // entitlements
    const {}, // allPurchaseDates
    const [], // activeSubscriptions
    const [], // allPurchasedProductIdentifiers
    const [], // nonSubscriptionTransactions
    '2026-07-13T16:00:00Z', // firstSeen
    'originalAppUserId', // originalAppUserId
    const {}, // allExpirationDates
    '2026-07-13T16:00:00Z', // requestDate
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockPurchasesWrapper mockPurchases;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockPurchases = MockPurchasesWrapper(
      initialCustomerInfo: createMockCustomerInfo(isPremium: false),
    );
    PremiumProvider.isPremiumStatic = false;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('PremiumProvider loads false by default when cache is empty', () async {
    final provider = PremiumProvider(purchases: mockPurchases);
    await provider.init();
    expect(provider.isPremium, false);
    expect(PremiumProvider.isPremiumStatic, false);
  });

  test('PremiumProvider loads true if cache has true', () async {
    SharedPreferences.setMockInitialValues({'premium_status_cached': true});
    final mockPurchasesPremium = MockPurchasesWrapper(
      initialCustomerInfo: createMockCustomerInfo(isPremium: true),
    );
    final provider = PremiumProvider(purchases: mockPurchasesPremium);
    await provider.init();
    expect(provider.isPremium, true);
    expect(PremiumProvider.isPremiumStatic, true);
  });

  test('updatePremiumStatus updates state, persists to cache and notifies listeners', () async {
    final provider = PremiumProvider(purchases: mockPurchases);
    await provider.init();
    
    int notifyCount = 0;
    provider.addListener(() {
      notifyCount++;
    });

    await provider.updatePremiumStatus(true);
    expect(provider.isPremium, true);
    expect(PremiumProvider.isPremiumStatic, true);
    expect(notifyCount, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('premium_status_cached'), true);
  });

  test('PremiumProvider configures Purchases and updates status from customer info on init', () async {
    final mockPurchasesPremium = MockPurchasesWrapper(
      initialCustomerInfo: createMockCustomerInfo(isPremium: true),
    );
    final provider = PremiumProvider(purchases: mockPurchasesPremium);
    await provider.init();

    expect(provider.isPremium, true);
    expect(mockPurchasesPremium.configureCallCount, 1);
    expect(mockPurchasesPremium.configuredLogLevel, LogLevel.debug);
  });

  test('PremiumProvider configures Purchases with Android API key on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final provider = PremiumProvider(purchases: mockPurchases);
    await provider.init();
    expect(mockPurchases.configuredApiKey, RevenueCatConfig.apiKeyAndroid);
  });

  test('PremiumProvider configures Purchases with iOS API key on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final provider = PremiumProvider(purchases: mockPurchases);
    await provider.init();
    expect(mockPurchases.configuredApiKey, RevenueCatConfig.apiKeyIOS);
  });

  test('PremiumProvider updates status when Purchases listener triggers update', () async {
    final provider = PremiumProvider(purchases: mockPurchases);
    await provider.init();
    expect(provider.isPremium, false);

    int notifyCount = 0;
    provider.addListener(() {
      notifyCount++;
    });

    mockPurchases.triggerUpdate(createMockCustomerInfo(isPremium: true));
    
    expect(provider.isPremium, true);
    expect(notifyCount, 1);
  });

  test('PremiumProvider handles getCustomerInfo error gracefully during init', () async {
    final mockPurchasesError = MockPurchasesWrapper(
      initialCustomerInfo: createMockCustomerInfo(isPremium: false),
      throwOnGetCustomerInfo: true,
    );
    final provider = PremiumProvider(purchases: mockPurchasesError);
    
    // Should initialize successfully without throwing exception
    await provider.init();
    expect(provider.isPremium, false);
    expect(mockPurchasesError.listeners.length, 1); // listener should still be registered
  });

  test('PremiumProvider handles configure error gracefully during init', () async {
    final mockPurchasesConfigError = MockPurchasesWrapper(
      initialCustomerInfo: createMockCustomerInfo(isPremium: false),
      throwOnConfigure: true,
    );
    final provider = PremiumProvider(purchases: mockPurchasesConfigError);
    
    // Should initialize successfully and fallback without throwing exception
    await provider.init();
    expect(provider.isPremium, false);
    expect(mockPurchasesConfigError.configureCallCount, 0); // threw before count incremented or failed configure
  });
}
