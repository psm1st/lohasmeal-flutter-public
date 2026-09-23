package com.lohasmeal.coklog

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Clears legacy per-minute / visibility alarm schedules from older builds.
 * Absolute timestamp labels no longer need periodic or home-visible redraws.
 */
object CoklogWidgetTicker {
  const val ACTION = "com.lohasmeal.action.COKLOG_WIDGET_TICK"
  private const val REQUEST_CODE = 44021

  fun cancelLegacyAlarms(context: Context) {
    val appContext = context.applicationContext
    val manager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    manager.cancel(pendingIntent(appContext))
  }

  private fun pendingIntent(context: Context): PendingIntent {
    val intent = Intent(context, CoklogWidgetTickReceiver::class.java).setAction(ACTION)
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
  }
}

class CoklogWidgetTickReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    when (intent?.action) {
      Intent.ACTION_BOOT_COMPLETED,
      CoklogWidgetTicker.ACTION,
      -> CoklogWidgetTicker.cancelLegacyAlarms(context)
    }
  }
}
