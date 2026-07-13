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
}

class PremiumProvider extends ChangeNotifier {
  static bool isPremiumStatic = false;

  bool _isPremium = false;
  bool get isPremium => _isPremium;
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
    final active = customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
    await updatePremiumStatus(active);
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
}
