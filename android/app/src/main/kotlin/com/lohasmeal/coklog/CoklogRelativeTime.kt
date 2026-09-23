package com.lohasmeal.coklog

import java.util.Calendar

/**
 * Widget time label as a **static absolute timestamp** (e.g. `14:25 기록`).
 * Does not depend on "now", so the widget only needs a redraw when snapshot data changes.
 */
object CoklogRelativeTime {
  fun formatLabel(recordedAtMs: Long, includeClock: Boolean): String {
    val cal = Calendar.getInstance().apply { timeInMillis = recordedAtMs }
    val hour = cal.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
    val minute = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
    val time = "$hour:$minute"
    val today = Calendar.getInstance()
    val sameDay =
      cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
        cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
    val stamp = if (sameDay) {
      time
    } else {
      val mm = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
      val dd = cal.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
      "$mm.$dd $time"
    }
    return if (includeClock) "$stamp 기록" else stamp
  }

  fun resolveDisplayLabel(
    recordedAtMs: Long?,
    fallbackRelativeLabel: String?,
    includeClock: Boolean,
  ): String? {
    if (recordedAtMs != null && recordedAtMs > 0) {
      return formatLabel(recordedAtMs, includeClock)
    }
    return fallbackRelativeLabel?.takeIf { it.isNotEmpty() }
  }
}
