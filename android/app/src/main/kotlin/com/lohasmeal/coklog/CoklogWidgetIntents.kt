package com.lohasmeal.coklog

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.lohasmeal.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent

object CoklogWidgetIntents {
  const val APP_GROUP_ID = "group.com.lohasmeal.coklog"

  fun tileUri(opensInApp: Boolean, moduleId: String): Uri {
    return Uri.Builder()
      .scheme("cokloghost")
      .authority(if (opensInApp) "open" else "quickLog")
      .appendQueryParameter("moduleId", moduleId)
      .appendQueryParameter("homeWidget", "1")
      .appendQueryParameter("appGroup", APP_GROUP_ID)
      .build()
  }

  fun pendingForTile(
    context: Context,
    opensInApp: Boolean,
    moduleId: String,
  ): PendingIntent {
    val uri = tileUri(opensInApp, moduleId)
    val requestCode = requestCode(opensInApp, moduleId)
    return if (opensInApp) {
      launchActivity(context, uri, requestCode)
    } else {
      quickLogBroadcast(context, uri, requestCode)
    }
  }

  private fun requestCode(opensInApp: Boolean, moduleId: String): Int {
    val prefix = if (opensInApp) 1_000 else 2_000
    return prefix + (moduleId.hashCode() and 0x7FFF)
  }

  private fun pendingFlags(): Int {
    var flags = PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT >= 23) {
      flags = flags or PendingIntent.FLAG_IMMUTABLE
    }
    return flags
  }

  private fun launchActivity(context: Context, uri: Uri, requestCode: Int): PendingIntent {
    val intent = Intent(context, MainActivity::class.java).apply {
      data = uri
      action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
    }
    val flags = pendingFlags()
    if (Build.VERSION.SDK_INT < 34) {
      return PendingIntent.getActivity(context, requestCode, intent, flags)
    }
    val options = ActivityOptions.makeBasic()
    if (Build.VERSION.SDK_INT >= 35) {
      options.setPendingIntentCreatorBackgroundActivityStartMode(
        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
      )
    } else {
      options.pendingIntentBackgroundActivityStartMode =
        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
    }
    return PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
  }

  private fun quickLogBroadcast(context: Context, uri: Uri, requestCode: Int): PendingIntent {
    val intent = Intent(context, CoklogQuickLogReceiver::class.java).apply {
      action = CoklogQuickLogReceiver.ACTION
      data = uri
    }
    return PendingIntent.getBroadcast(context, requestCode, intent, pendingFlags())
  }
}
