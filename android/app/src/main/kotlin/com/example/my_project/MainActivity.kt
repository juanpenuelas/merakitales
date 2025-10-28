package com.merakily.merakitales

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.MediaView

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
        adView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )

        // Root vertical container
        val container = LinearLayout(context)
        container.orientation = LinearLayout.VERTICAL
        container.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )

        // Media view for image/video (16:9 can be managed by parent height in Flutter)
        val mediaView = MediaView(context)
        // Use a fixed height to avoid overflowing outside the NativeAdView. Adjust as needed.
        val mediaLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(context, 180)
        )
        mediaView.layoutParams = mediaLp

        // Headline
        val title = TextView(context)
        title.textSize = 16f
        title.setPadding(16, 12, 16, 4)

        // Body text
        val body = TextView(context)
        body.textSize = 14f
        body.setPadding(16, 0, 16, 8)
        body.maxLines = 2

        // Footer with optional icon and CTA button
        val footer = LinearLayout(context)
        footer.orientation = LinearLayout.HORIZONTAL
        footer.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        footer.setPadding(0, 8, 16, 12)

        val iconView = ImageView(context)
        val iconLp = LinearLayout.LayoutParams(64, 64)
        iconLp.setMargins(16, 8, 8, 12)
        iconView.layoutParams = iconLp

        val spacer = View(context)
        val spacerLp = LinearLayout.LayoutParams(0, 0)
        spacerLp.weight = 1f
        spacer.layoutParams = spacerLp

        val cta = Button(context)
        cta.textSize = 14f
        val ctaParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        cta.layoutParams = ctaParams
        cta.setPadding(16, 8, 16, 12)

        // Assign views to the adView
        adView.mediaView = mediaView
        adView.headlineView = title
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = iconView

        // Populate available assets
        title.text = nativeAd.headline
        body.text = nativeAd.body
        cta.text = nativeAd.callToAction
        nativeAd.icon?.let { iconView.setImageDrawable(it.drawable) } ?: run {
            iconView.visibility = View.GONE
        }

        // KEY: assign media content so image/video renders
        adView.mediaView?.mediaContent = nativeAd.mediaContent

        // Build view hierarchy
        container.addView(mediaView)
        container.addView(title)
        container.addView(body)
        footer.addView(iconView)
        footer.addView(spacer)
        footer.addView(cta)
        container.addView(footer)
        adView.addView(container)

        adView.setNativeAd(nativeAd)
        return adView
    }
}

// Helper to convert dp to pixels for consistent sizing
private fun dp(ctx: Context, value: Int): Int = (ctx.resources.displayMetrics.density * value).toInt()
