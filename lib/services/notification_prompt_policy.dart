import 'package:shared_preferences/shared_preferences.dart';

/// Politica de reofertas del pre-dialogo de notificaciones. Logica pura
/// sobre SharedPreferences, sin tocar firebase, para poder testearla sin
/// plugins.
class NotificationPromptPolicy {
  static const int kFirstOfferAtOpens = 2;
  static const int kOpensBetweenOffers = 5;
  static const int kMaxOffers = 3;

  static const String _opensCountKey = 'notif_opens_count';
  static const String _offersMadeKey = 'notif_offers_made';
  static const String _nextOfferAtKey = 'notif_next_offer_at';
  static const String _doneKey = 'notif_done';

  Future<void> recordTaleOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final opens = (prefs.getInt(_opensCountKey) ?? 0) + 1;
    await prefs.setInt(_opensCountKey, opens);
  }

  Future<bool> shouldOfferNow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return false;

    final offersMade = prefs.getInt(_offersMadeKey) ?? 0;
    if (offersMade >= kMaxOffers) return false;

    final opensCount = prefs.getInt(_opensCountKey) ?? 0;
    final threshold = offersMade == 0
        ? kFirstOfferAtOpens
        : (prefs.getInt(_nextOfferAtKey) ?? kFirstOfferAtOpens);
    return opensCount >= threshold;
  }

  Future<void> recordOfferShown() async {
    final prefs = await SharedPreferences.getInstance();
    final opensCount = prefs.getInt(_opensCountKey) ?? 0;
    final offersMade = (prefs.getInt(_offersMadeKey) ?? 0) + 1;
    await prefs.setInt(_offersMadeKey, offersMade);
    await prefs.setInt(_nextOfferAtKey, opensCount + kOpensBetweenOffers);
  }

  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }
}
