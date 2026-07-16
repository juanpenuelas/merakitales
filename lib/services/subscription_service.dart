import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_config.dart';

class PurchasesWrapper {
  const PurchasesWrapper();
  Future<void> configure(String apiKey) => Purchases.configure(PurchasesConfiguration(apiKey));
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) =>
      Purchases.addCustomerInfoUpdateListener(listener);
  Future<void> setLogLevel(LogLevel level) => Purchases.setLogLevel(level);
  Future<Offerings> getOfferings() => Purchases.getOfferings();
  Future<CustomerInfo> purchasePackage(Package package) => Purchases.purchasePackage(package);
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();
}

class PremiumProvider extends ChangeNotifier {
  static bool isPremiumStatic = false;

  bool _isPremium = false;
  bool get isPremium => _isPremium;
  
  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  final PurchasesWrapper _purchases;
  SharedPreferences? _prefs;

  PremiumProvider({
    PurchasesWrapper purchases = const PurchasesWrapper(),
  }) : _purchases = purchases;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isPremium = _prefs?.getBool('premium_status_cached') ?? false;
    isPremiumStatic = _isPremium;

    if (kIsWeb) {
      debugPrint("RevenueCat is not supported on Web.");
      return;
    }

    try {
      await _purchases.setLogLevel(LogLevel.debug);

      final apiKey = (defaultTargetPlatform == TargetPlatform.android)
          ? RevenueCatConfig.apiKeyAndroid
          : RevenueCatConfig.apiKeyIOS;

      await _purchases.configure(apiKey);

      _purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateWithCustomerInfo(customerInfo);
      });

      try {
        final customerInfo = await _purchases.getCustomerInfo();
        await _updateWithCustomerInfo(customerInfo);
      } catch (e) {
        debugPrint("Failed to fetch initial customer info: $e");
      }
    } catch (e) {
      debugPrint("RevenueCat failed to initialize: $e");
    }
  }

  Future<void> _updateWithCustomerInfo(CustomerInfo customerInfo) async {
    _customerInfo = customerInfo;
    final active = customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
    
    final wasPremium = _isPremium;
    await updatePremiumStatus(active);
    
    // If updatePremiumStatus didn't trigger a notification, trigger one for the customerInfo update
    if (wasPremium == active) {
      notifyListeners();
    }
  }

  Future<void> updatePremiumStatus(bool active) async {
    isPremiumStatic = active;
    if (_isPremium != active) {
      _isPremium = active;
      notifyListeners();
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.setBool('premium_status_cached', active);
      } catch (e) {
        debugPrint("Failed to write premium status to cache: $e");
      }
    }
  }

  Offerings? _offerings;
  Offerings? get offerings => _offerings;
  bool _isLoadingOfferings = false;
  bool get isLoadingOfferings => _isLoadingOfferings;

  Future<void> loadOfferings() async {
    if (kIsWeb) return;
    _isLoadingOfferings = true;
    notifyListeners();
    try {
      _offerings = await _purchases.getOfferings();
    } catch (e) {
      debugPrint("Failed to load RevenueCat offerings: $e");
    } finally {
      _isLoadingOfferings = false;
      notifyListeners();
    }
  }

  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await _purchases.purchasePackage(package);
      await _updateWithCustomerInfo(customerInfo);
      return customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint("Purchase failed: $e");
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await _purchases.restorePurchases();
      await _updateWithCustomerInfo(customerInfo);
      return customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint("Restore failed: $e");
      return false;
    }
  }
}
