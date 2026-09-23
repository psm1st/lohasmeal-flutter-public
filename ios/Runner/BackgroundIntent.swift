import AppIntents
import Foundation
import WidgetKit

private let kQuickActionsKey = "coklog_widget_quick_actions"
private let kSnapshotKey = "coklog_widget_snapshot"
private let kAmountHintsKey = "coklog_widget_amount_hints"
private let kBootstrapKey = "coklog_module_bootstrap"
private let kDefaultAppGroup = "group.com.lohasmeal.coklog"

enum CoklogWidgetQuickActionQueue {
  static func enqueue(url: URL?, appGroup: String?) -> [String: Any]? {
    guard let url else { return nil }
    let group = appGroup ?? kDefaultAppGroup
    guard let defaults = UserDefaults(suiteName: group) else { return nil }
    guard let moduleId = moduleId(from: url) else { return nil }

    var items: [[String: Any]] = []
    if let raw = defaults.string(forKey: kQuickActionsKey),
       let data = raw.data(using: .utf8),
       let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    {
      items = arr
    }

    let action: [String: Any] = [
      "id": UUID().uuidString,
      "moduleId": moduleId,
      "recordedAtMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    items.append(action)

    guard let encoded = try? JSONSerialization.data(withJSONObject: items),
          let str = String(data: encoded, encoding: .utf8)
    else { return nil }

    defaults.set(str, forKey: kQuickActionsKey)
    defaults.synchronize()
    NSLog("CoklogWidgetQuickActionQueue: enqueued %@", moduleId)
    return action
  }

  static func remove(id: String, appGroup: String?) {
    let group = appGroup ?? kDefaultAppGroup
    guard let defaults = UserDefaults(suiteName: group),
          let raw = defaults.string(forKey: kQuickActionsKey),
          let data = raw.data(using: .utf8),
          let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return }

    let remaining = items.filter { ($0["id"] as? String) != id }
    guard let encoded = try? JSONSerialization.data(withJSONObject: remaining),
          let str = String(data: encoded, encoding: .utf8)
    else { return }
    defaults.set(str, forKey: kQuickActionsKey)
    defaults.synchronize()
  }

  static func moduleId(from url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "moduleId" })?
      .value
  }
}

enum CoklogNativeQuickLogSync {
  static func sync(action: [String: Any], appGroup: String?) async -> Bool {
    let group = appGroup ?? kDefaultAppGroup
    guard let defaults = UserDefaults(suiteName: group),
          let raw = defaults.string(forKey: kBootstrapKey)
            ?? defaults.string(forKey: "flutter.\(kBootstrapKey)"),
          let bootstrapData = raw.data(using: .utf8),
          let bootstrap = try? JSONSerialization.jsonObject(with: bootstrapData) as? [String: Any],
          let base = bootstrap["serverBaseUrl"] as? String,
          let token = bootstrap["accessToken"] as? String,
          !token.isEmpty,
          let memberId = bootstrap["memberId"] as? Int,
          let childId = bootstrap["childId"] as? Int,
          let moduleId = action["moduleId"] as? String,
          let actionId = action["id"] as? String,
          let recordedAtMs = action["recordedAtMs"] as? Int,
          let recordType = recordType(for: moduleId)
    else {
      NSLog("CoklogNativeQuickLogSync: missing bootstrap")
      return false
    }

    let body = recordBody(
      moduleId: moduleId,
      actionId: actionId,
      recordedAtMs: recordedAtMs,
      bootstrap: bootstrap,
      defaults: defaults
    )
    guard let body else { return false }

    let prefix = base.hasSuffix("/") ? String(base.dropLast()) : base
    let root = "\(prefix)/api/v1/members/\(memberId)/children/\(childId)"
    guard await post(
      url: "\(root)/records/\(recordType)",
      body: body,
      token: token
    ) else {
      return false
    }

    return true
  }

  private static func post(url: String, body: [String: Any], token: String) async -> Bool {
    guard let endpoint = URL(string: url),
          let data = try? JSONSerialization.data(withJSONObject: body)
    else { return false }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 10
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = data
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { return false }
      return (200...299).contains(http.statusCode)
    } catch {
      NSLog("CoklogNativeQuickLogSync: %@", error.localizedDescription)
      return false
    }
  }

  private static func recordBody(
    moduleId: String,
    actionId: String,
    recordedAtMs: Int,
    bootstrap: [String: Any],
    defaults: UserDefaults
  ) -> [String: Any]? {
    let recordedAt = localTimestamp(recordedAtMs)
    let hints = amountHints(defaults)
    let meta: [String: Any] = [
      "clientRecordId": actionId,
      "categoryId": moduleId,
      "title": title(for: moduleId),
      "displayValue": displayValue(for: moduleId, defaults: defaults) ?? NSNull(),
      "recordedAt": recordedAtMs,
    ]
    switch moduleId {
    case "bottle":
      return ["recordedAt": recordedAt, "amount": hints["bottle"] ?? 0, "_coklog": meta]
    case "pump":
      return ["recordedAt": recordedAt, "amount": hints["pump"] ?? 0, "_coklog": meta]
    case "breast":
      return ["recordedAt": recordedAt, "breastFeedingOrder": "NONE",
              "leftMinutes": 0, "rightMinutes": 0, "_coklog": meta]
    case "poop":
      return ["recordedAt": recordedAt, "poopAmount": "NORMAL",
              "poopTexture": "NORMAL", "poopColor": "BROWN", "_coklog": meta]
    case "urine", "pill", "vomit":
      return ["recordedAt": recordedAt, "_coklog": meta]
    case "baby-food":
      guard let composeId = bootstrap["orderLineComposeId"] as? Int else { return nil }
      return ["recordedAt": recordedAt, "amount": hints["babyFood"] ?? 0,
              "orderLineComposeId": composeId, "feedbackType": "NONE", "_coklog": meta]
    default:
      return nil
    }
  }

  private static func localTimestamp(_ milliseconds: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000))
  }

  private static func amountHints(_ defaults: UserDefaults) -> [String: Int] {
    guard let raw = defaults.string(forKey: kAmountHintsKey)
            ?? defaults.string(forKey: "flutter.\(kAmountHintsKey)"),
          let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return json.reduce(into: [String: Int]()) { result, item in
      if let value = item.value as? Int { result[item.key] = value }
      if let value = item.value as? NSNumber { result[item.key] = value.intValue }
    }
  }

  private static func recordType(for moduleId: String) -> String? {
    [
      "baby-food": "ordered-ingests", "breast": "breast-feedings",
      "bottle": "lactations", "pump": "expressed-milks", "poop": "poops",
      "urine": "urine", "pill": "medications", "vomit": "vomits",
    ][moduleId]
  }

  private static func title(for moduleId: String) -> String {
    [
      "baby-food": "이유식", "breast": "모유", "bottle": "수유",
      "pump": "유축수유", "poop": "대변", "urine": "소변",
      "pill": "투약", "vomit": "구토",
    ][moduleId] ?? moduleId
  }

  private static func displayValue(for moduleId: String, defaults: UserDefaults) -> String? {
    let hints = amountHints(defaults)
    switch moduleId {
    case "bottle": return "\(hints["bottle"] ?? 0)ml"
    case "pump": return "\(hints["pump"] ?? 0)ml"
    case "baby-food": return "\(hints["babyFood"] ?? 0)g"
    default: return nil
    }
  }
}

enum CoklogOptimisticSnapshot {
  static func apply(moduleId: String, appGroup: String?) {
    let group = appGroup ?? kDefaultAppGroup
    guard let defaults = UserDefaults(suiteName: group) else { return }

    let raw = defaults.string(forKey: kSnapshotKey)
      ?? defaults.string(forKey: "flutter.\(kSnapshotKey)")
    guard let raw,
          let data = raw.data(using: .utf8),
          var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var tiles = root["tiles"] as? [[String: Any]]
    else {
      NSLog("CoklogOptimisticSnapshot: no snapshot to patch")
      return
    }

    let nowMs = Int(Date().timeIntervalSince1970 * 1000)
    let hints = loadHints(defaults: defaults)
    let display = optimisticDisplay(moduleId: moduleId, hints: hints)

    for i in 0..<tiles.count {
      guard (tiles[i]["moduleId"] as? String) == moduleId else { continue }
      if let display {
        tiles[i]["displayValue"] = display
      } else {
        tiles[i]["displayValue"] = "기록"
      }
      tiles[i]["recordedAt"] = nowMs
      tiles[i]["relativeLabel"] = "방금"
    }

    root["tiles"] = tiles
    root["updatedAt"] = nowMs

    guard let out = try? JSONSerialization.data(withJSONObject: root),
          let str = String(data: out, encoding: .utf8)
    else { return }

    defaults.set(str, forKey: kSnapshotKey)
    defaults.synchronize()
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    NSLog("CoklogOptimisticSnapshot: patched %@", moduleId)
  }

  private static func loadHints(defaults: UserDefaults) -> [String: Int] {
    guard let raw = defaults.string(forKey: kAmountHintsKey)
            ?? defaults.string(forKey: "flutter.\(kAmountHintsKey)"),
          let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    var out: [String: Int] = [:]
    for (k, v) in json {
      if let n = v as? Int { out[k] = n }
      else if let n = v as? NSNumber { out[k] = n.intValue }
    }
    return out
  }

  private static func optimisticDisplay(moduleId: String, hints: [String: Int]) -> String? {
    switch moduleId {
    case "bottle": return "\(hints["bottle"] ?? 0)ml"
    case "pump": return "\(hints["pump"] ?? 0)ml"
    case "baby-food": return "\(hints["babyFood"] ?? 0)g"
    default: return nil
    }
  }
}

@available(iOS 17, *)
public struct BackgroundIntent: AppIntent {
  static public var title: LocalizedStringResource = "Coklog Widget Quick Log"

  static public var openAppWhenRun: Bool = false

  @Parameter(title: "Widget URI")
  var url: URL?

  @Parameter(title: "AppGroup")
  var appGroup: String?

  public init() {}

  public init(url: URL?, appGroup: String?) {
    self.url = url
    self.appGroup = appGroup
  }

  public func perform() async throws -> some IntentResult {
    let group = appGroup ?? kDefaultAppGroup
    NSLog("BackgroundIntent.perform url=%@", url?.absoluteString ?? "nil")

    if let url, let moduleId = CoklogWidgetQuickActionQueue.moduleId(from: url) {
      CoklogOptimisticSnapshot.apply(moduleId: moduleId, appGroup: group)
    }

    // Enqueue only — Flutter drains via miniapp API (v2). Legacy BFF POST removed.
    _ = CoklogWidgetQuickActionQueue.enqueue(url: url, appGroup: group)

    return .result()
  }
}

@available(iOS 17, *)
public struct OpenMiniappIntent: AppIntent {
  static public var title: LocalizedStringResource = "Coklog Open Miniapp"

  static public var openAppWhenRun: Bool = true

  @Parameter(title: "Widget URI")
  var url: URL?

  @Parameter(title: "AppGroup")
  var appGroup: String?

  public init() {}

  public init(url: URL?, appGroup: String?) {
    self.url = url
    self.appGroup = appGroup
  }

  public func perform() async throws -> some IntentResult {
    let group = appGroup ?? kDefaultAppGroup
    guard let url else { return .result() }
    NSLog("OpenMiniappIntent.perform url=%@", url.absoluteString)

    let defaults = UserDefaults(suiteName: group)
    let key = "coklog_widget_launch_url"
    defaults?.set(url.absoluteString, forKey: key)
    defaults?.set(url.absoluteString, forKey: "flutter.\(key)")
    defaults?.synchronize()
    return .result()
  }
}

@available(iOS 26, *)
extension BackgroundIntent {
  public static var supportedModes: IntentModes {
    [.background, .foreground(.dynamic)]
  }
}

@available(iOS 26, *)
extension OpenMiniappIntent {
  public static var supportedModes: IntentModes {
    [.background, .foreground(.dynamic)]
  }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension BackgroundIntent: ForegroundContinuableIntent {}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension OpenMiniappIntent: ForegroundContinuableIntent {}
