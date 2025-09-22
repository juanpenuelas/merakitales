import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  static const String _iosAdUnitId = 'ca-app-pub-6049242703708474/2668880303';
  static const String _androidAdUnitId = 'ca-app-pub-6049242703708474/6416553624';

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb) {
      // Native ads are not supported on web.
      return;
    }
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final adUnitId = isAndroid ? _androidAdUnitId : _iosAdUnitId;
    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
    nativeAd.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }
    // IMPORTANT: Native Ad platform views require a bounded size.
    // Give the AdWidget an explicit height to avoid unbounded layout errors in slivers.
    final double adHeight = widget.height ?? 120; // default 120, override as needed

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(8.0),
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        child: SizedBox(
          height: adHeight,
          width: double.infinity,
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }
}
