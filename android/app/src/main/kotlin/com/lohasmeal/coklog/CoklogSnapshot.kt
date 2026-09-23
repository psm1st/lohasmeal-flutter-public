package com.lohasmeal.coklog

import org.json.JSONObject

data class CoklogTile(
  val moduleId: String,
  val title: String,
  val colorHex: String,
  val opensInApp: Boolean,
  val displayValue: String?,
  val relativeLabel: String?,
  val recordedAtMs: Long?,
)

data class CoklogSnapshot(
  val version: Int?,
  val saved: Boolean,
  val size: String,
  val placeholderMessage: String?,
  val tiles: List<CoklogTile>,
) {
  companion object {
    const val KEY = "coklog_widget_snapshot"
    const val DEFAULT_PLACEHOLDER = "미니앱에서 위젯을 설정하세요"

    fun fromJson(raw: String?): CoklogSnapshot? {
      if (raw.isNullOrEmpty()) return null
      return try {
        val json = JSONObject(raw)
        val tilesJson = json.optJSONArray("tiles")
        val tiles = mutableListOf<CoklogTile>()
        if (tilesJson != null) {
          for (i in 0 until tilesJson.length()) {
            val item = tilesJson.optJSONObject(i) ?: continue
            val recordedAt = when {
              item.has("recordedAt") && !item.isNull("recordedAt") -> item.optLong("recordedAt")
              else -> null
            }?.takeIf { it > 0 }
            tiles.add(
              CoklogTile(
                moduleId = item.optString("moduleId"),
                title = item.optString("title"),
                colorHex = item.optString("colorHex", "#94A3B8"),
                opensInApp = item.optBoolean("opensInApp", false),
                displayValue = item.optNullableString("displayValue"),
                relativeLabel = item.optNullableString("relativeLabel"),
                recordedAtMs = recordedAt,
              ),
            )
          }
        }
        CoklogSnapshot(
          version = if (json.has("version")) json.optInt("version") else null,
          saved = json.optBoolean("saved", false),
          size = json.optString("size", "square"),
          placeholderMessage = json.optNullableString("placeholderMessage"),
          tiles = tiles,
        )
      } catch (_: Exception) {
        null
      }
    }

    private fun JSONObject.optNullableString(key: String): String? {
      if (!has(key) || isNull(key)) return null
      val value = optString(key)
      return value.takeIf { it.isNotEmpty() }
    }
  }
}
