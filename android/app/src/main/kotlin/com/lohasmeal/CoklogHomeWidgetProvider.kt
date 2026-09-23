package com.lohasmeal

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import com.lohasmeal.coklog.CoklogHomeWidgetViews
import com.lohasmeal.coklog.CoklogSnapshot
import com.lohasmeal.coklog.CoklogWidgetTicker
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

open class CoklogHomeWidget : HomeWidgetProvider() {
  companion object {
    fun refreshAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, CoklogHomeWidget::class.java))
      if (ids.isEmpty()) return
      CoklogHomeWidget().onUpdate(
        context,
        manager,
        ids,
        HomeWidgetPlugin.getData(context),
      )
    }
  }

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    val snapshot = CoklogSnapshot.fromJson(
      widgetData.getString(CoklogSnapshot.KEY, null)
        ?: widgetData.getString("flutter.${CoklogSnapshot.KEY}", null),
    )
    appWidgetIds.forEach { widgetId ->
      val options = appWidgetManager.getAppWidgetOptions(widgetId)
      val family = CoklogHomeWidgetViews.familyForSize(
        minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
        minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT),
        snapshotSize = snapshot?.size,
      )
      val views = CoklogHomeWidgetViews.build(context, snapshot, family)
      appWidgetManager.updateAppWidget(widgetId, views)
    }
    // Absolute labels — no ticker. Drop any legacy AlarmManager schedules.
    CoklogWidgetTicker.cancelLegacyAlarms(context)
  }

  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    CoklogWidgetTicker.cancelLegacyAlarms(context)
  }

  override fun onDisabled(context: Context) {
    CoklogWidgetTicker.cancelLegacyAlarms(context)
    super.onDisabled(context)
  }

  override fun onAppWidgetOptionsChanged(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    newOptions: Bundle,
  ) {
    onUpdate(
      context,
      appWidgetManager,
      intArrayOf(appWidgetId),
      HomeWidgetPlugin.getData(context),
    )
  }
}

class CoklogHomeWidgetProvider : CoklogHomeWidget()
