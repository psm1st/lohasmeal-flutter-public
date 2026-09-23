package com.lohasmeal.coklog

enum class CoklogCategorySection {
  CARE,
  GROWTH,
}

data class CoklogCategory(
  val id: String,
  val title: String,
  val colorHex: String,
  val assetName: String,
  val opensInApp: Boolean,
  val section: CoklogCategorySection,
)

object CoklogCategories {
  const val MAX_HOME_WIDGET_TILES = 16

  val care: List<CoklogCategory> = listOf(
    CoklogCategory("baby-food", "이유식", "#FF8C42", "icon_baby_food", false, CoklogCategorySection.CARE),
    CoklogCategory("breast", "모유", "#5E6AD2", "icon_breast", false, CoklogCategorySection.CARE),
    CoklogCategory("bottle", "수유", "#3B82F6", "icon_bottle", false, CoklogCategorySection.CARE),
    CoklogCategory("pump", "유축수유", "#06B6D4", "icon_pump", false, CoklogCategorySection.CARE),
    CoklogCategory("temp", "체온", "#F43F5E", "icon_temp", true, CoklogCategorySection.CARE),
    CoklogCategory("poop", "대변", "#84CC16", "icon_poop", false, CoklogCategorySection.CARE),
    CoklogCategory("urine", "소변", "#22D3EE", "icon_urine", false, CoklogCategorySection.CARE),
    CoklogCategory("pill", "투약", "#A855F7", "icon_pill", true, CoklogCategorySection.CARE),
    CoklogCategory("vomit", "구토", "#64748B", "icon_vomit", false, CoklogCategorySection.CARE),
    CoklogCategory("memo", "메모", "#0EA5E9", "icon_memo", true, CoklogCategorySection.CARE),
  )

  val growth: List<CoklogCategory> = listOf(
    CoklogCategory("height", "키", "#10B981", "icon_height", true, CoklogCategorySection.GROWTH),
    CoklogCategory("weight", "몸무게", "#F59E0B", "icon_weight", true, CoklogCategorySection.GROWTH),
    CoklogCategory("head", "머리", "#EC4899", "icon_head", true, CoklogCategorySection.GROWTH),
    CoklogCategory("chest", "가슴", "#8B5CF6", "icon_chest", true, CoklogCategorySection.GROWTH),
  )

  val all: List<CoklogCategory> = care + growth

  private val byId: Map<String, CoklogCategory> = all.associateBy { it.id }
  private val byTitle: Map<String, CoklogCategory> = all.associateBy { it.title }

  fun resolve(moduleId: String?, title: String?): CoklogCategory? {
    val id = moduleId?.trim().orEmpty()
    if (id.isNotEmpty()) {
      byId[id]?.let { return it }
      when (id.lowercase()) {
        "yugsik", "babyfood", "solid" -> return byId["baby-food"]
        "moyu", "breastmilk" -> return byId["breast"]
        "suyu", "formula" -> return byId["bottle"]
        "yuchuk" -> return byId["pump"]
        "temperature", "fever" -> return byId["temp"]
        "daebyeon", "stool" -> return byId["poop"]
        "sobyeon", "pee" -> return byId["urine"]
        "tuyak", "medicine", "med" -> return byId["pill"]
        "guto" -> return byId["vomit"]
        "key", "신장" -> return byId["height"]
        "momuge", "체중" -> return byId["weight"]
        "meori" -> return byId["head"]
        "gaseum" -> return byId["chest"]
      }
    }
    val t = title?.trim().orEmpty()
    if (t.isNotEmpty()) return byTitle[t]
    return null
  }
}
