package com.lohasmeal.coklog

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import com.lohasmeal.CoklogHomeWidget
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

object CoklogNativeQuickLog {
  private const val TAG = "CoklogQuickLog"
  private const val SNAPSHOT_KEY = "coklog_widget_snapshot"
  private const val QUICK_ACTIONS_KEY = "coklog_widget_quick_actions"
  private const val AMOUNT_HINTS_KEY = "coklog_widget_amount_hints"
  private const val BOOTSTRAP_KEY = "coklog_module_bootstrap"

  fun handle(context: Context, uri: Uri?) {
    val moduleId = uri?.getQueryParameter("moduleId")?.trim().orEmpty()
    if (moduleId.isEmpty()) {
      Log.w(TAG, "missing moduleId uri=$uri")
      return
    }

    Log.i(TAG, "handle moduleId=$moduleId")
    applyOptimistic(context, moduleId)
    CoklogHomeWidget.refreshAll(context)

    // Enqueue only — Flutter drains via miniapp API (v2). Legacy BFF POST removed.
    enqueue(context, moduleId)
  }

  private fun prefs(context: Context): SharedPreferences =
    HomeWidgetPlugin.getData(context)

  private fun prefString(prefs: SharedPreferences, key: String): String? {
    return prefs.getString(key, null)?.takeIf { it.isNotEmpty() }
      ?: prefs.getString("flutter.$key", null)?.takeIf { it.isNotEmpty() }
  }

  private fun putString(prefs: SharedPreferences, key: String, value: String) {
    prefs.edit()
      .putString(key, value)
      .putString("flutter.$key", value)
      .commit()
  }

  private fun enqueue(context: Context, moduleId: String): JSONObject? {
    val prefs = prefs(context)
    val items = try {
      JSONArray(prefString(prefs, QUICK_ACTIONS_KEY) ?: "[]")
    } catch (_: Exception) {
      JSONArray()
    }
    val action = JSONObject()
      .put("id", UUID.randomUUID().toString())
      .put("moduleId", moduleId)
      .put("recordedAtMs", System.currentTimeMillis())
    items.put(action)
    putString(prefs, QUICK_ACTIONS_KEY, items.toString())
    Log.i(TAG, "enqueued $moduleId")
    return action
  }

  private fun remove(context: Context, id: String) {
    val prefs = prefs(context)
    val raw = prefString(prefs, QUICK_ACTIONS_KEY) ?: return
    val items = JSONArray(raw)
    val remaining = JSONArray()
    for (i in 0 until items.length()) {
      val item = items.optJSONObject(i) ?: continue
      if (item.optString("id") != id) remaining.put(item)
    }
    putString(prefs, QUICK_ACTIONS_KEY, remaining.toString())
  }

  private fun sync(context: Context, action: JSONObject): Boolean {
    val prefs = prefs(context)
    val bootstrapRaw = prefString(prefs, BOOTSTRAP_KEY)
    if (bootstrapRaw.isNullOrEmpty()) {
      Log.w(TAG, "missing bootstrap")
      return false
    }
    val bootstrap = try {
      JSONObject(bootstrapRaw)
    } catch (_: Exception) {
      Log.w(TAG, "bootstrap JSON")
      return false
    }
    val base = bootstrap.optString("serverBaseUrl").trimEnd('/')
    val token = bootstrap.optString("accessToken")
    val memberId = bootstrap.optInt("memberId")
    val childId = bootstrap.optInt("childId")
    val moduleId = action.optString("moduleId")
    val actionId = action.optString("id")
    val recordedAtMs = action.optLong("recordedAtMs")
    val recordType = recordType(moduleId)
    if (base.isEmpty() || token.isEmpty() || memberId <= 0 || childId <= 0 || recordType == null) {
      Log.w(TAG, "incomplete bootstrap memberId=$memberId childId=$childId")
      return false
    }
    val body = recordBody(moduleId, actionId, recordedAtMs, bootstrap, prefs) ?: return false
    val root = "$base/api/v1/members/$memberId/children/$childId"
    return post("$root/records/$recordType", body, token)
  }

  private fun post(url: String, body: JSONObject, token: String): Boolean {
    var conn: HttpURLConnection? = null
    return try {
      conn = (URL(url).openConnection() as HttpURLConnection).apply {
        requestMethod = "POST"
        connectTimeout = 10_000
        readTimeout = 10_000
        doOutput = true
        setRequestProperty("Content-Type", "application/json")
        setRequestProperty("Authorization", "Bearer $token")
      }
      conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
      val code = conn.responseCode
      val ok = code in 200..299
      if (!ok) Log.w(TAG, "POST $url -> $code")
      ok
    } catch (e: Exception) {
      Log.e(TAG, "POST $url failed", e)
      false
    } finally {
      conn?.disconnect()
    }
  }

  private fun recordBody(
    moduleId: String,
    actionId: String,
    recordedAtMs: Long,
    bootstrap: JSONObject,
    prefs: SharedPreferences,
  ): JSONObject? {
    val recordedAt = localTimestamp(recordedAtMs)
    val hints = amountHints(prefs)
    val meta = JSONObject()
      .put("clientRecordId", actionId)
      .put("categoryId", moduleId)
      .put("title", title(moduleId))
      .put("displayValue", displayValue(moduleId, prefs) ?: JSONObject.NULL)
      .put("recordedAt", recordedAtMs)
    return when (moduleId) {
      "bottle" -> JSONObject()
        .put("recordedAt", recordedAt)
        .put("amount", hints["bottle"] ?: 0)
        .put("_coklog", meta)
      "pump" -> JSONObject()
        .put("recordedAt", recordedAt)
        .put("amount", hints["pump"] ?: 0)
        .put("_coklog", meta)
      "breast" -> JSONObject()
        .put("recordedAt", recordedAt)
        .put("breastFeedingOrder", "NONE")
        .put("leftMinutes", 0)
        .put("rightMinutes", 0)
        .put("_coklog", meta)
      "poop" -> JSONObject()
        .put("recordedAt", recordedAt)
        .put("poopAmount", "NORMAL")
        .put("poopTexture", "NORMAL")
        .put("poopColor", "BROWN")
        .put("_coklog", meta)
      "urine", "pill", "vomit" -> JSONObject()
        .put("recordedAt", recordedAt)
        .put("_coklog", meta)
      "baby-food" -> {
        if (!bootstrap.has("orderLineComposeId") || bootstrap.isNull("orderLineComposeId")) {
          return null
        }
        val composeId = bootstrap.optInt("orderLineComposeId")
        if (composeId <= 0) return null
        JSONObject()
          .put("recordedAt", recordedAt)
          .put("amount", hints["babyFood"] ?: 0)
          .put("orderLineComposeId", composeId)
          .put("feedbackType", "NONE")
          .put("_coklog", meta)
      }
      else -> null
    }
  }

  private fun localTimestamp(milliseconds: Long): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
    return formatter.format(Date(milliseconds))
  }

  private fun amountHints(prefs: SharedPreferences): Map<String, Int> {
    val raw = prefString(prefs, AMOUNT_HINTS_KEY) ?: return emptyMap()
    return try {
      val json = JSONObject(raw)
      json.keys().asSequence().associateWith { json.optInt(it) }
    } catch (_: Exception) {
      emptyMap()
    }
  }

  private fun recordType(moduleId: String): String? = when (moduleId) {
    "baby-food" -> "ordered-ingests"
    "breast" -> "breast-feedings"
    "bottle" -> "lactations"
    "pump" -> "expressed-milks"
    "poop" -> "poops"
    "urine" -> "urine"
    "pill" -> "medications"
    "vomit" -> "vomits"
    else -> null
  }

  private fun title(moduleId: String): String = when (moduleId) {
    "baby-food" -> "이유식"
    "breast" -> "모유"
    "bottle" -> "수유"
    "pump" -> "유축수유"
    "poop" -> "대변"
    "urine" -> "소변"
    "pill" -> "투약"
    "vomit" -> "구토"
    else -> moduleId
  }

  private fun displayValue(moduleId: String, prefs: SharedPreferences): String? {
    val hints = amountHints(prefs)
    return when (moduleId) {
      "bottle" -> "${hints["bottle"] ?: 0}ml"
      "pump" -> "${hints["pump"] ?: 0}ml"
      "baby-food" -> "${hints["babyFood"] ?: 0}g"
      else -> null
    }
  }

  private fun applyOptimistic(context: Context, moduleId: String) {
    val prefs = prefs(context)
    val raw = prefString(prefs, SNAPSHOT_KEY) ?: run {
      Log.w(TAG, "no snapshot to patch")
      return
    }
    try {
      val root = JSONObject(raw)
      val tiles = root.optJSONArray("tiles") ?: return
      val nowMs = System.currentTimeMillis()
      val display = displayValue(moduleId, prefs) ?: "기록"
      for (i in 0 until tiles.length()) {
        val tile = tiles.optJSONObject(i) ?: continue
        if (tile.optString("moduleId") != moduleId) continue
        tile.put("displayValue", display)
        tile.put("recordedAt", nowMs)
        tile.put("relativeLabel", "방금")
      }
      root.put("tiles", tiles)
      root.put("updatedAt", nowMs)
      putString(prefs, SNAPSHOT_KEY, root.toString())
      Log.i(TAG, "patched snapshot $moduleId")
    } catch (e: Exception) {
      Log.e(TAG, "optimistic patch failed", e)
    }
  }
}
