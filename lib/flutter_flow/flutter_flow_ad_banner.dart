import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:merakitales/services/subscription_service.dart';

class FlutterFlowAdBanner extends StatefulWidget {
  const FlutterFlowAdBanner({
    Key? key,
    this.width,
    this.height,
    required this.showsTestAd,
    this.iOSAdUnitID,
    this.androidAdUnitID,
  }) : super(key: key);

  final double? width;
  final double? height;
  final bool showsTestAd;
  final String? iOSAdUnitID;
  final String? androidAdUnitID;

  @override
  _FlutterFlowAdBannerState createState() => _FlutterFlowAdBannerState();
}

class _FlutterFlowAdBannerState extends State<FlutterFlowAdBanner> {
  static const AdRequest request = AdRequest();

  BannerAd? _anchoredBanner;
  AdWidget? adWidget;
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

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _createAnchoredBanner(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final isPremium = Provider.of<PremiumProvider>(context).isPremium;
      if (isPremium && _anchoredBanner != null) {
        _safeDisposeAd(_anchoredBanner);
        _anchoredBanner = null;
        adWidget = null;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _safeDisposeAd(_anchoredBanner);
    _anchoredBanner = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = Provider.of<PremiumProvider>(context).isPremium;
    if (isPremium) {
      return const SizedBox.shrink();
    }

    var loadingText = 'Ad Loading... \n\n';
    if (widget.showsTestAd) {
      loadingText +=
          'If this takes a long time, you may have to check whether the ad is '
          'being covered from a parent widget. For example, a larger width than '
          'the device screen size or a large border radius encompassing the ad banner '
          'may stop ads from loading.\n\n'
          'If a full-width banner is desired for your app, leave the width and '
          'height of the AdBanner widget empty. AdBanner will automatically'
          'match the size of the banner to the device screen.';
    }

    return _anchoredBanner != null && adWidget != null
        ? Container(
            alignment: Alignment.center,
            color: Colors.red,
            width: _anchoredBanner!.size.width.toDouble(),
            height: _anchoredBanner!.size.height.toDouble(),
            child: adWidget,
          )
        : Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                loadingText,
                style: const TextStyle(
                  fontSize: 10.0,
                  color: Colors.white,
                ),
              ),
            ),
          );
  }

  Future _createAnchoredBanner(BuildContext context) async {
    if (!mounted) return;
    final isPremium = Provider.of<PremiumProvider>(context, listen: false).isPremium;
    if (isPremium) {
      return;
    }

    final AdSize? size = widget.width != null && widget.height != null
        ? AdSize(
            height: widget.height!.toInt(),
            width: widget.width!.toInt(),
          )
        : await AdSize.getAnchoredAdaptiveBannerAdSize(
            widget.width == null ? Orientation.portrait : Orientation.landscape,
            widget.width == null
                ? MediaQuery.sizeOf(context).width.truncate()
                : MediaQuery.sizeOf(context).height.truncate(),
          );

    if (size == null) {
      print('Unable to get size of anchored banner.');
      return;
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;
    _safeDisposeAd(_anchoredBanner);

    final BannerAd banner = BannerAd(
      size: size,
      request: request,
      adUnitId: widget.showsTestAd
          ? isAndroid
              ? 'ca-app-pub-3940256099942544/6300978111'
              : 'ca-app-pub-3940256099942544/2934735716'
          : isAndroid
              ? widget.androidAdUnitID!
              : widget.iOSAdUnitID!,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('$BannerAd loaded.');
          if (_anchoredBanner != ad) {
            _safeDisposeAd(ad);
            return;
          }
          if (!mounted) return;
          final isPremiumNow = Provider.of<PremiumProvider>(context, listen: false).isPremium;
          if (isPremiumNow) {
            _safeDisposeAd(ad);
            _anchoredBanner = null;
            adWidget = null;
            return;
          }
          setState(() {
            _anchoredBanner = ad as BannerAd;
            adWidget = AdWidget(ad: ad);
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('$BannerAd failedToLoad: $error');
          if (_anchoredBanner != ad) {
            _safeDisposeAd(ad);
            return;
          }
          _safeDisposeAd(ad);
          _anchoredBanner = null;
          adWidget = null;
          if (mounted) {
            setState(() {});
          }
        },
        onAdOpened: (Ad ad) => print('$BannerAd onAdOpened.'),
        onAdClosed: (Ad ad) => print('$BannerAd onAdClosed.'),
      ),
    );

    _anchoredBanner = banner;
    await banner.load();
    return;
  }
}
