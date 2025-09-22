package com.merakily.merakitales

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "listTile", ListTileNativeAdFactory(this))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

class ListTileNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = NativeAdView(context)
        val container = LinearLayout(context)
        container.orientation = LinearLayout.VERTICAL
        container.layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        val title = TextView(context)
        title.textSize = 16f
        title.setPadding(16, 16, 16, 8)
        val cta = Button(context)
        cta.textSize = 14f
        val ctaParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        ctaParams.gravity = Gravity.END
        cta.layoutParams = ctaParams
        cta.setPadding(16, 8, 16, 16)

        // Assign views to the ad view.
        adView.headlineView = title
        adView.callToActionView = cta

        // Populate the views.
        title.text = nativeAd.headline
        cta.text = nativeAd.callToAction

        container.addView(title)
        container.addView(cta)
        adView.addView(container)
        adView.setNativeAd(nativeAd)
        return adView
    }
}
