package com.lohasmeal.coklog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.concurrent.Executors

class CoklogQuickLogReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val pending = goAsync()
    val appContext = context.applicationContext
    val uri = intent.data
    EXECUTOR.execute {
      try {
        CoklogNativeQuickLog.handle(appContext, uri)
      } finally {
        pending.finish()
      }
    }
  }

  companion object {
    const val ACTION = "com.lohasmeal.action.COKLOG_QUICK_LOG"
    private val EXECUTOR = Executors.newSingleThreadExecutor()
  }
}
