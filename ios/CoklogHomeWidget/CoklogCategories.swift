import SwiftUI

/// Host-side category catalog mirrored from coklog
/// `apps/web/src/constants/widgetModules.ts` + Figma node `1:411` (위젯 컬러 카탈로그).
enum CoklogCategoryId: String, CaseIterable, Identifiable {
  case babyFood = "baby-food"
  case breast = "breast"
  case bottle = "bottle"
  case pump = "pump"
  case temp = "temp"
  case poop = "poop"
  case urine = "urine"
  case pill = "pill"
  case vomit = "vomit"
  case memo = "memo"
  case height = "height"
  case weight = "weight"
  case head = "head"
  case chest = "chest"

  var id: String { rawValue }
}

enum CoklogCategorySection: String {
  case care
  case growth
}

struct CoklogCategory: Identifiable, Equatable {
  let id: CoklogCategoryId
  let title: String
  let colorHex: String
  let assetName: String
  /// `true` → open in app (↗); `false` → quick log (+)
  let opensInApp: Bool
  let section: CoklogCategorySection

  var color: Color { Color(hex: colorHex) }
}

enum CoklogCategories {
  static let maxHomeWidgetTiles = 16

  static let all: [CoklogCategory] = care + growth

  static let care: [CoklogCategory] = [
    .init(id: .babyFood, title: "이유식", colorHex: "#FF8C42", assetName: "icon_baby_food", opensInApp: false, section: .care),
    .init(id: .breast, title: "모유", colorHex: "#5E6AD2", assetName: "icon_breast", opensInApp: false, section: .care),
    .init(id: .bottle, title: "수유", colorHex: "#3B82F6", assetName: "icon_bottle", opensInApp: false, section: .care),
    .init(id: .pump, title: "유축수유", colorHex: "#06B6D4", assetName: "icon_pump", opensInApp: false, section: .care),
    .init(id: .temp, title: "체온", colorHex: "#F43F5E", assetName: "icon_temp", opensInApp: true, section: .care),
    .init(id: .poop, title: "대변", colorHex: "#84CC16", assetName: "icon_poop", opensInApp: false, section: .care),
    .init(id: .urine, title: "소변", colorHex: "#22D3EE", assetName: "icon_urine", opensInApp: false, section: .care),
    .init(id: .pill, title: "투약", colorHex: "#A855F7", assetName: "icon_pill", opensInApp: true, section: .care),
    .init(id: .vomit, title: "구토", colorHex: "#64748B", assetName: "icon_vomit", opensInApp: false, section: .care),
    .init(id: .memo, title: "메모", colorHex: "#0EA5E9", assetName: "icon_memo", opensInApp: true, section: .care),
  ]

  static let growth: [CoklogCategory] = [
    .init(id: .height, title: "키", colorHex: "#10B981", assetName: "icon_height", opensInApp: true, section: .growth),
    .init(id: .weight, title: "몸무게", colorHex: "#F59E0B", assetName: "icon_weight", opensInApp: true, section: .growth),
    .init(id: .head, title: "머리", colorHex: "#EC4899", assetName: "icon_head", opensInApp: true, section: .growth),
    .init(id: .chest, title: "가슴", colorHex: "#8B5CF6", assetName: "icon_chest", opensInApp: true, section: .growth),
  ]

  private static let byId: [String: CoklogCategory] = {
    Dictionary(uniqueKeysWithValues: all.map { ($0.id.rawValue, $0) })
  }()

  private static let byTitle: [String: CoklogCategory] = {
    Dictionary(uniqueKeysWithValues: all.map { ($0.title, $0) })
  }()

  static func resolve(moduleId: String?, title: String?) -> CoklogCategory? {
    if let id = moduleId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
      if let hit = byId[id] { return hit }
      // legacy / alias ids
      switch id.lowercased() {
      case "yugsik", "babyfood", "solid": return byId["baby-food"]
      case "moyu", "breastmilk": return byId["breast"]
      case "suyu", "formula": return byId["bottle"]
      case "yuchuk": return byId["pump"]
      case "che온", "temperature", "fever": return byId["temp"]
      case "daebyeon", "stool": return byId["poop"]
      case "sobyeon", "pee": return byId["urine"]
      case "tuyak", "medicine", "med": return byId["pill"]
      case "guto": return byId["vomit"]
      case "key", "신장": return byId["height"]
      case "momuge", "체중": return byId["weight"]
      case "meori": return byId["head"]
      case "gaseum": return byId["chest"]
      default: break
      }
    }
    if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
      if let hit = byTitle[t] { return hit }
    }
    return nil
  }

  static func assetName(moduleId: String?, title: String?) -> String? {
    resolve(moduleId: moduleId, title: title)?.assetName
  }

  static func colorHex(moduleId: String?, title: String?, fallback: String) -> String {
    resolve(moduleId: moduleId, title: title)?.colorHex ?? fallback
  }
}

extension Color {
  init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r, g, b: UInt64
    switch cleaned.count {
    case 6:
      (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (148, 163, 184)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: 1
    )
  }
}
