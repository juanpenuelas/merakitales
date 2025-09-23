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
    // Important: Let Flutter/Platform View manage the frame. Don't disable autoresizing on the container view.
    adView.translatesAutoresizingMaskIntoConstraints = true

    // Media (image/video)
    let media = MediaView()
    media.translatesAutoresizingMaskIntoConstraints = false
    media.contentMode = .scaleAspectFill
    media.clipsToBounds = true
    adView.mediaView = media
    adView.addSubview(media)

    // Headline
    let title = UILabel()
    title.numberOfLines = 2
    title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    title.translatesAutoresizingMaskIntoConstraints = false
    adView.headlineView = title
    adView.addSubview(title)

    // Body
    let body = UILabel()
    body.numberOfLines = 2
    body.font = UIFont.systemFont(ofSize: 14)
    body.translatesAutoresizingMaskIntoConstraints = false
    adView.bodyView = body
    adView.addSubview(body)

    // Footer with optional icon and CTA
    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFit
    adView.iconView = iconView
    adView.addSubview(iconView)

    let cta = UIButton(type: .system)
    cta.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
    cta.translatesAutoresizingMaskIntoConstraints = false
    adView.callToActionView = cta
    adView.addSubview(cta)

    // Layout constraints
    var constraints: [NSLayoutConstraint] = [
      // Media on top with 16:9 ratio
      media.topAnchor.constraint(equalTo: adView.topAnchor),
      media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      media.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      media.heightAnchor.constraint(equalTo: media.widthAnchor, multiplier: 9.0/16.0),

      // Title below media
      title.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 8),
      title.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
      title.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),

      // Body below title
      body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
      body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
      body.trailingAnchor.constraint(equalTo: title.trailingAnchor),

      // Icon and CTA at bottom
      iconView.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 8),
      iconView.leadingAnchor.constraint(equalTo: body.leadingAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 40),
      iconView.heightAnchor.constraint(equalToConstant: 40),

      cta.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
      cta.trailingAnchor.constraint(equalTo: body.trailingAnchor),
      cta.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),

      // Keep some spacing between icon and CTA
      iconView.trailingAnchor.constraint(lessThanOrEqualTo: cta.leadingAnchor, constant: -8)
    ]

    // Fallback bottom constraints in case CTA is hidden (ensure layout doesn't collapse)
    constraints.append(body.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor, constant: -12))
    constraints.append(title.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor, constant: -12))
    constraints.append(media.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor, constant: -12))

    NSLayoutConstraint.activate(constraints)

    // Populate with available assets (guard against nils)
    (adView.headlineView as? UILabel)?.text = nativeAd.headline
    (adView.bodyView as? UILabel)?.text = nativeAd.body
    if let callToAction = nativeAd.callToAction {
      (adView.callToActionView as? UIButton)?.setTitle(callToAction, for: .normal)
      adView.callToActionView?.isHidden = false
    } else {
      adView.callToActionView?.isHidden = true
    }
    if let icon = nativeAd.icon?.image {
      (adView.iconView as? UIImageView)?.image = icon
      adView.iconView?.isHidden = false
    } else {
      adView.iconView?.isHidden = true
    }

    // KEY: assign media content so image/video renders
    adView.mediaView?.mediaContent = nativeAd.mediaContent

    adView.nativeAd = nativeAd
    return adView
  }
}
