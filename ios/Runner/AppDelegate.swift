import UIKit
import Flutter
import google_mobile_ads
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register Native Ad Factory for rendering native ads from Flutter.
    let listTileFactory = ListTileNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "listTile", nativeAdFactory: listTileFactory)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class ListTileNativeAdFactory: FLTNativeAdFactory {
  func createNativeAd(_ nativeAd: GoogleMobileAds.NativeAd, customOptions: [AnyHashable : Any]? = nil) -> GoogleMobileAds.NativeAdView? {
    let adView = GoogleMobileAds.NativeAdView(frame: .zero)

    // Simple vertical stack with headline and CTA button
    let container = UIStackView()
    container.axis = .vertical
    container.alignment = .fill
    container.distribution = .fill
    container.spacing = 8

    let title = UILabel()
    title.numberOfLines = 2
    title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

    let cta = UIButton(type: .system)
    cta.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
    cta.contentHorizontalAlignment = .right

    adView.headlineView = title
    adView.callToActionView = cta

    // Populate with available assets (guard against nils)
    (adView.headlineView as? UILabel)?.text = nativeAd.headline
    if let callToAction = nativeAd.callToAction {
      (adView.callToActionView as? UIButton)?.setTitle(callToAction, for: .normal)
    } else {
      adView.callToActionView?.isHidden = true
    }

    adView.addSubview(container)
    container.addArrangedSubview(title)
    container.addArrangedSubview(cta)

    container.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
      container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12)
    ])

    adView.nativeAd = nativeAd
    return adView
  }
}
