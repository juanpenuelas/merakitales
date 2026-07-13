import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode, kProfileMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:merakitales/services/subscription_service.dart';

// Global toggle for Native Ads: set to true to use AdMob test unit IDs, false for production IDs.
const bool kNativeAdsShowTestAds = false;

class NativeAdListTile extends StatefulWidget {
  const NativeAdListTile({super.key, this.height});

  // Optional explicit height to better fit different layouts (e.g., tablet).
  final double? height;

  @override
  State<NativeAdListTile> createState() => _NativeAdListTileState();
}

class _NativeAdListTileState extends State<NativeAdListTile> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;

  static const String _iosAdUnitId = 'ca-app-pub-6049242703708474/2668880303';
  static const String _androidAdUnitId = 'ca-app-pub-6049242703708474/6416553624';

  final Expando<bool> _disposedAds = Expando('disposedAds');

  void _safeDisposeAd(Ad? ad) {
    if (ad == null) return;
    if (_disposedAds[ad] == true) return;
    _disposedAds[ad] = true;
    try {
      ad.dispose();
    } catch (e) {
      debugPrint('Error disposing ad: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _scheduleRetry() {
    if (!mounted) return;
    try {
      final isPremium = Provider.of<PremiumProvider>(context, listen: false).isPremium;
      if (isPremium) {
        return;
      }
    } catch (_) {}

    final delayMs = (1000 * (1 << _retryAttempt)).clamp(1000, 30000);
    debugPrint('[NativeAd] scheduling retry in ${delayMs}ms (attempt=${_retryAttempt + 1})');
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _loadAd();
    });
    _retryAttempt = (_retryAttempt + 1).clamp(0, 5);
  }

  void _loadAd() {
    if (kIsWeb) {
      // Native ads are not supported on web.
      return;
    }
    try {
      final isPremium = Provider.of<PremiumProvider>(context, listen: false).isPremium;
      if (isPremium) {
        return;
      }
    } catch (_) {}

    if (_isLoading || _isLoaded) {
      return;
    }
    _isLoading = true;

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    // Use test ad units in Debug or Profile builds, or if manually forced.
    final bool useTestAds = kNativeAdsShowTestAds || kDebugMode || kProfileMode;
    final adUnitId = isAndroid
        ? (useTestAds
            ? 'ca-app-pub-3940256099942544/2247696110' // Android Native Advanced (test)
            : _androidAdUnitId)
        : (useTestAds
            ? 'ca-app-pub-3940256099942544/3986624511' // iOS Native Advanced (test)
            : _iosAdUnitId);

    debugPrint('[NativeAd] useTestAds=$useTestAds, platform=${isAndroid ? 'android' : 'ios'}, adUnitId=$adUnitId');

    _safeDisposeAd(_nativeAd);

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (_nativeAd != ad) {
            _safeDisposeAd(ad);
            return;
          }
          if (!mounted) return;
          final isPremiumNow = Provider.of<PremiumProvider>(context, listen: false).isPremium;
          if (isPremiumNow) {
            _safeDisposeAd(ad);
            _nativeAd = null;
            _isLoaded = false;
            _isLoading = false;
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _isLoading = false;
            _retryAttempt = 0; // reset backoff
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          _isLoading = false;
          if (_nativeAd != ad) {
            _safeDisposeAd(ad);
            return;
          }
          _safeDisposeAd(ad);
          _nativeAd = null;
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
          // Retry on no-fill/code 1 and other transient errors.
          _scheduleRetry();
        },
      ),
    );
    _nativeAd!.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final isPremium = Provider.of<PremiumProvider>(context).isPremium;
      if (isPremium && _nativeAd != null) {
        _safeDisposeAd(_nativeAd);
        _nativeAd = null;
        _isLoaded = false;
        _isLoading = false;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _safeDisposeAd(_nativeAd);
    _nativeAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = Provider.of<PremiumProvider>(context).isPremium;
    if (isPremium) {
      return const SizedBox.shrink();
    }

    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(8.0),
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Compute a reasonable height: media 16:9 + ~100px text/CTA.
            final w = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
            final mediaH = w / (16 / 9);
            const textH = 100.0;
            final computed = mediaH + textH;
            final h = (widget.height ?? computed).clamp(220.0, 420.0);
            return SizedBox(
              height: h,
              width: double.infinity,
              child: AdWidget(ad: _nativeAd!),
            );
          },
        ),
      ),
    );
  }
}
