package com.lohasmeal.coklog

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.lohasmeal.R

enum class CoklogWidgetFamily {
  SMALL,
  MEDIUM,
  LARGE,
}

enum class TileProminence {
  COMPACT,
  REGULAR,
  LARGE,
}

object CoklogHomeWidgetViews {
  fun build(
    context: Context,
    snapshot: CoklogSnapshot?,
    family: CoklogWidgetFamily,
  ): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.coklog_widget_root)
    val tiles = snapshot?.tiles?.take(CoklogCategories.MAX_HOME_WIDGET_TILES).orEmpty()
    val showTiles = snapshot?.saved == true && tiles.isNotEmpty()

    if (!showTiles) {
      views.setViewVisibility(R.id.widget_grid, View.GONE)
      views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
      views.setTextViewText(
        R.id.widget_placeholder,
        snapshot?.placeholderMessage ?: CoklogSnapshot.DEFAULT_PLACEHOLDER,
      )
      return views
    }

    views.setViewVisibility(R.id.widget_placeholder, View.GONE)
    views.setViewVisibility(R.id.widget_grid, View.VISIBLE)
    views.removeAllViews(R.id.widget_grid)
    // Landscape omits clock; square/large match module includeClock for square size.
    val includeClock = family != CoklogWidgetFamily.MEDIUM
    addLayout(context, views, tiles, family, includeClock)
    return views
  }

  private fun addLayout(
    context: Context,
    root: RemoteViews,
    tiles: List<CoklogTile>,
    family: CoklogWidgetFamily,
    includeClock: Boolean,
  ) {
    when (family) {
      CoklogWidgetFamily.MEDIUM -> addLandscapeLayout(context, root, tiles, includeClock)
      CoklogWidgetFamily.LARGE -> addLargeLayout(context, root, tiles, includeClock)
      CoklogWidgetFamily.SMALL -> addSquareLayout(context, root, tiles, includeClock)
    }
  }

  private fun addSquareLayout(
    context: Context,
    root: RemoteViews,
    tiles: List<CoklogTile>,
    includeClock: Boolean,
  ) {
    val regular = TileProminence.REGULAR
    when (tiles.size) {
      1 -> addRow(context, root, listOf(tiles[0] to regular), includeClock = includeClock)
      2 -> addRow(
        context,
        root,
        listOf(tiles[0] to TileProminence.LARGE, tiles[1] to TileProminence.LARGE),
        includeClock = includeClock,
      )
      3 -> {
        addRow(context, root, listOf(tiles[0] to TileProminence.LARGE), includeClock = includeClock)
        addGapV(context, root)
        addRow(
          context,
          root,
          listOf(tiles[1] to regular, tiles[2] to regular),
          includeClock = includeClock,
        )
      }
      else -> {
        addRow(
          context,
          root,
          listOf(tiles[0] to regular, tiles[1] to regular),
          includeClock = includeClock,
        )
        addGapV(context, root)
        val bottom = mutableListOf(tiles[2] to regular)
        if (tiles.size > 3) bottom.add(tiles[3] to regular)
        addRow(context, root, bottom, includeClock = includeClock)
      }
    }
  }

  private fun addLandscapeLayout(
    context: Context,
    root: RemoteViews,
    tiles: List<CoklogTile>,
    includeClock: Boolean,
  ) {
    when (tiles.size) {
      1 -> addRow(context, root, listOf(tiles[0] to TileProminence.LARGE), includeClock = includeClock)
      2 -> addRow(
        context,
        root,
        listOf(tiles[0] to TileProminence.LARGE, tiles[1] to TileProminence.LARGE),
        includeClock = includeClock,
      )
      3 -> addRow(
        context,
        root,
        listOf(
          tiles[0] to TileProminence.LARGE,
          tiles[1] to TileProminence.COMPACT,
          tiles[2] to TileProminence.COMPACT,
        ),
        wideFirst = true,
        includeClock = includeClock,
      )
      else -> addRow(
        context,
        root,
        tiles.take(4).map { it to TileProminence.COMPACT },
        includeClock = includeClock,
      )
    }
  }

  private fun addLargeLayout(
    context: Context,
    root: RemoteViews,
    tiles: List<CoklogTile>,
    includeClock: Boolean,
  ) {
    if (tiles.size <= 4) {
      addSquareLayout(context, root, tiles, includeClock)
      return
    }
    val rows = tiles.chunked(4)
    rows.forEachIndexed { index, rowTiles ->
      if (index > 0) addGapV(context, root)
      val cells = rowTiles.map { it to TileProminence.COMPACT }.toMutableList()
      addRow(context, root, cells, padTo = 4, includeClock = includeClock)
    }
  }

  private fun addRow(
    context: Context,
    root: RemoteViews,
    cells: List<Pair<CoklogTile, TileProminence>>,
    wideFirst: Boolean = false,
    padTo: Int = 0,
    includeClock: Boolean = true,
  ) {
    val row = RemoteViews(context.packageName, R.layout.coklog_widget_row)
    cells.forEachIndexed { index, (tile, prominence) ->
      if (index > 0) {
        row.addView(R.id.widget_row, RemoteViews(context.packageName, R.layout.coklog_widget_gap_h))
      }
      val wide = wideFirst && index == 0 && prominence == TileProminence.LARGE
      row.addView(R.id.widget_row, buildCell(context, tile, prominence, wide, includeClock))
    }
    val missing = (padTo - cells.size).coerceAtLeast(0)
    repeat(missing) {
      row.addView(R.id.widget_row, RemoteViews(context.packageName, R.layout.coklog_widget_gap_h))
      row.addView(R.id.widget_row, RemoteViews(context.packageName, R.layout.coklog_widget_spacer))
    }
    root.addView(R.id.widget_grid, row)
  }

  private fun addGapV(context: Context, root: RemoteViews) {
    root.addView(R.id.widget_grid, RemoteViews(context.packageName, R.layout.coklog_widget_gap_v))
  }

  private fun buildCell(
    context: Context,
    tile: CoklogTile,
    prominence: TileProminence,
    wide: Boolean,
    includeClock: Boolean,
  ): RemoteViews {
    val layout = if (wide) R.layout.coklog_widget_cell_wide else R.layout.coklog_widget_cell
    val cell = RemoteViews(context.packageName, layout)
    val catalog = CoklogCategories.resolve(tile.moduleId, tile.title)
    val fill = parseColor(catalog?.colorHex ?: tile.colorHex)
    val opensInApp = catalog?.opensInApp ?: tile.opensInApp

    cell.setInt(R.id.cell_bg, "setColorFilter", fill)
    applyProminence(context, cell, prominence, wide)

    val iconName = catalog?.assetName
    val iconId = if (iconName != null) {
      context.resources.getIdentifier(iconName, "drawable", context.packageName)
    } else {
      0
    }
    if (iconId != 0) {
      cell.setImageViewResource(R.id.cell_icon, iconId)
      cell.setViewVisibility(R.id.cell_icon, View.VISIBLE)
    } else {
      cell.setViewVisibility(R.id.cell_icon, View.INVISIBLE)
    }
    cell.setImageViewResource(
      R.id.cell_action,
      if (opensInApp) R.drawable.icon_launch else R.drawable.icon_plus,
    )

    cell.setTextViewText(R.id.cell_title, tile.title)
    cell.setTextViewText(R.id.cell_value, tile.displayValue?.takeIf { it.isNotEmpty() } ?: "—")
    val relative = CoklogRelativeTime.resolveDisplayLabel(
      recordedAtMs = tile.recordedAtMs,
      fallbackRelativeLabel = tile.relativeLabel,
      includeClock = includeClock,
    )
    if (relative.isNullOrEmpty()) {
      cell.setViewVisibility(R.id.cell_relative, View.GONE)
    } else {
      cell.setViewVisibility(R.id.cell_relative, View.VISIBLE)
      cell.setTextViewText(R.id.cell_relative, relative)
    }

    cell.setOnClickPendingIntent(
      R.id.cell_root,
      CoklogWidgetIntents.pendingForTile(context, opensInApp, tile.moduleId),
    )
    return cell
  }

  private fun applyProminence(
    context: Context,
    cell: RemoteViews,
    prominence: TileProminence,
    wide: Boolean,
  ) {
    if (wide) return
    val titleSize: Float
    val valueSize: Float
    val timeSize: Float
    val padDp: Int
    when (prominence) {
      TileProminence.COMPACT -> {
        titleSize = 11f
        valueSize = 16f
        timeSize = 10f
        padDp = 10
      }
      TileProminence.REGULAR -> {
        titleSize = 11f
        valueSize = 17f
        timeSize = 10f
        padDp = 10
      }
      TileProminence.LARGE -> {
        titleSize = 12f
        valueSize = 19f
        timeSize = 11f
        padDp = 12
      }
    }
    cell.setTextViewTextSize(R.id.cell_title, TypedValue.COMPLEX_UNIT_SP, titleSize)
    cell.setTextViewTextSize(R.id.cell_value, TypedValue.COMPLEX_UNIT_SP, valueSize)
    cell.setTextViewTextSize(R.id.cell_relative, TypedValue.COMPLEX_UNIT_SP, timeSize)
    val px = TypedValue.applyDimension(
      TypedValue.COMPLEX_UNIT_DIP,
      padDp.toFloat(),
      context.resources.displayMetrics,
    ).toInt()
    cell.setViewPadding(R.id.cell_content, px, px, px, px)
  }

  fun parseColor(hex: String): Int {
    val cleaned = hex.trim().removePrefix("#")
    return try {
      when (cleaned.length) {
        6 -> Color.parseColor("#$cleaned")
        8 -> Color.parseColor("#$cleaned")
        else -> Color.parseColor("#94A3B8")
      }
    } catch (_: Exception) {
      Color.parseColor("#94A3B8")
    }
  }

  fun familyForSize(minWidthDp: Int, minHeightDp: Int, snapshotSize: String?): CoklogWidgetFamily {
    if (minWidthDp >= 250 && minHeightDp >= 200) return CoklogWidgetFamily.LARGE
    if (minWidthDp >= 250) return CoklogWidgetFamily.MEDIUM
    if (minHeightDp >= 200 && minWidthDp >= 180) return CoklogWidgetFamily.LARGE
    return when (snapshotSize) {
      "landscape" -> CoklogWidgetFamily.MEDIUM
      else -> CoklogWidgetFamily.SMALL
    }
  }
}
