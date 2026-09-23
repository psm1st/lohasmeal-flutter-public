import WidgetKit
import SwiftUI
import AppIntents

private let appGroupId = "group.com.lohasmeal.coklog"
private let snapshotKey = "coklog_widget_snapshot"

// MARK: - Snapshot models

struct CoklogTile: Decodable {
  let moduleId: String
  let title: String
  let colorHex: String
  let opensInApp: Bool
  let displayValue: String?
  let relativeLabel: String?
  let recordedAt: Int64?

  enum CodingKeys: String, CodingKey {
    case moduleId, title, colorHex, opensInApp, displayValue, relativeLabel, recordedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    moduleId = try c.decode(String.self, forKey: .moduleId)
    title = try c.decode(String.self, forKey: .title)
    colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#94A3B8"
    opensInApp = try c.decodeIfPresent(Bool.self, forKey: .opensInApp) ?? false
    displayValue = try c.decodeIfPresent(String.self, forKey: .displayValue)
    relativeLabel = try c.decodeIfPresent(String.self, forKey: .relativeLabel)
    if let ms = try c.decodeIfPresent(Int64.self, forKey: .recordedAt) {
      recordedAt = ms
    } else if let n = try c.decodeIfPresent(Double.self, forKey: .recordedAt) {
      recordedAt = Int64(n)
    } else {
      recordedAt = nil
    }
  }
}

struct CoklogSnapshot: Decodable {
  let version: Int?
  let saved: Bool
  let size: String
  let placeholderMessage: String?
  let tiles: [CoklogTile]
}

enum CoklogRelativeTime {
  static func resolveDisplayLabel(
    recordedAtMs: Int64?,
    fallback: String?,
    includeClock: Bool
  ) -> String? {
    if let ms = recordedAtMs, ms > 0 {
      return formatLabel(recordedAtMs: ms, includeClock: includeClock)
    }
    guard let fallback, !fallback.isEmpty else { return nil }
    return fallback
  }

  /// Static absolute stamp (e.g. `14:25 기록`). No dependency on "now" —
  /// widget redraw only needed when snapshot data changes.
  static func formatLabel(recordedAtMs: Int64, includeClock: Bool) -> String {
    let recorded = Date(timeIntervalSince1970: TimeInterval(recordedAtMs) / 1000.0)
    let cal = Calendar.current
    let hour = String(format: "%02d", cal.component(.hour, from: recorded))
    let minute = String(format: "%02d", cal.component(.minute, from: recorded))
    let time = "\(hour):\(minute)"
    let stamp: String
    if cal.isDateInToday(recorded) {
      stamp = time
    } else {
      let mm = String(format: "%02d", cal.component(.month, from: recorded))
      let dd = String(format: "%02d", cal.component(.day, from: recorded))
      stamp = "\(mm).\(dd) \(time)"
    }
    return includeClock ? "\(stamp) 기록" : stamp
  }
}
// MARK: - Timeline

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), snapshot: nil, family: context.family)
  }

  func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
    completion(SimpleEntry(date: Date(), snapshot: loadSnapshot(), family: context.family))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
    let snapshot = loadSnapshot()
    let family = context.family
    // Absolute timestamps — redraw only when snapshot / host reloads timelines.
    let entry = SimpleEntry(date: Date(), snapshot: snapshot, family: family)
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func loadSnapshot() -> CoklogSnapshot? {
    let defaults = UserDefaults(suiteName: appGroupId)
    guard let raw = defaults?.string(forKey: snapshotKey)
      ?? defaults?.string(forKey: "flutter.\(snapshotKey)"),
      let data = raw.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(CoklogSnapshot.self, from: data)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let snapshot: CoklogSnapshot?
  let family: WidgetFamily
}

// MARK: - Entry
/// Layout matrix from Figma node `1:32`. Cell chrome/icons from catalog `1:411`.
/// Tiles always expand to fill available width & height — never fixed square aspect.

struct CoklogHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    Group {
      if let snap = entry.snapshot, snap.saved, !snap.tiles.isEmpty {
        let tiles = Array(snap.tiles.prefix(CoklogCategories.maxHomeWidgetTiles))
        layout(tiles)
          .padding(10)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Text(entry.snapshot?.placeholderMessage ?? "미니앱에서 위젯을 설정하세요")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(10)
      }
    }
  }

  private var gap: CGFloat {
    switch entry.family {
    case .systemMedium, .systemLarge: return 6
    default: return 8
    }
  }

  private var landscape: Bool {
    entry.family == .systemMedium
  }

  @ViewBuilder
  private func layout(_ tiles: [CoklogTile]) -> some View {
    switch entry.family {
    case .systemMedium:
      landscapeLayout(tiles)
    case .systemLarge:
      largeLayout(tiles)
    default:
      squareLayout(tiles)
    }
  }

  // MARK: systemSmall — Figma 2×2 위젯

  @ViewBuilder
  private func squareLayout(_ tiles: [CoklogTile]) -> some View {
    let p = TileProminence.regular
    switch tiles.count {
    case 1:
      cell(tiles[0], p)
    case 2:
      HStack(spacing: gap) {
        cell(tiles[0], .large)
        cell(tiles[1], .large)
      }
    case 3:
      VStack(spacing: gap) {
        cell(tiles[0], .large)
        HStack(spacing: gap) {
          cell(tiles[1], p)
          cell(tiles[2], p)
        }
      }
    default:
      // 2×2 fills entire small widget
      VStack(spacing: gap) {
        HStack(spacing: gap) {
          cell(tiles[0], p)
          cell(tiles[1], p)
        }
        HStack(spacing: gap) {
          cell(tiles[2], p)
          if tiles.count > 3 { cell(tiles[3], p) }
        }
      }
    }
  }

  // MARK: systemMedium — Figma 4×2 위젯 (가로, 타일이 세로로 길쭉)

  @ViewBuilder
  private func landscapeLayout(_ tiles: [CoklogTile]) -> some View {
    switch tiles.count {
    case 1:
      cell(tiles[0], .large)
    case 2:
      HStack(spacing: gap) {
        cell(tiles[0], .large)
        cell(tiles[1], .large)
      }
    case 3:
      // Figma: left ~50%, right two ~25% each — full height
      GeometryReader { geo in
        let g = gap
        let unit = (geo.size.width - g * 2) / 4
        HStack(spacing: g) {
          cell(tiles[0], .large)
            .frame(width: unit * 2, height: geo.size.height)
          cell(tiles[1], .compact)
            .frame(width: unit, height: geo.size.height)
          cell(tiles[2], .compact)
            .frame(width: unit, height: geo.size.height)
        }
      }
    default:
      // 4 equal vertical strips filling medium height
      HStack(spacing: gap) {
        ForEach(Array(tiles.prefix(4).enumerated()), id: \.offset) { _, tile in
          cell(tile, .compact)
        }
      }
    }
  }

  // MARK: systemLarge — 4열 그리드가 위젯 전체를 채움 (최대 4×4)

  @ViewBuilder
  private func largeLayout(_ tiles: [CoklogTile]) -> some View {
    let count = tiles.count
    if count <= 4 {
      // 4개 이하면 Figma 2×2처럼 크게 채움 (한 줄 고정 금지)
      squareLayout(tiles)
    } else {
      let rows = stride(from: 0, to: count, by: 4).map { start in
        Array(tiles[start..<min(start + 4, count)])
      }
      VStack(spacing: gap) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          HStack(spacing: gap) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, tile in
              cell(tile, .compact)
            }
            // pad incomplete last row so cell widths stay even
            if row.count < 4 {
              ForEach(0..<(4 - row.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
              }
            }
          }
          .frame(maxHeight: .infinity)
        }
      }
    }
  }

  private func cell(_ tile: CoklogTile, _ prominence: TileProminence) -> some View {
    interactiveTile(tile, prominence: prominence)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
  }

  @ViewBuilder
  private func interactiveTile(_ tile: CoklogTile, prominence: TileProminence) -> some View {
    let content = WidgetCellView(
      tile: tile,
      prominence: prominence,
      includeClock: !landscape
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    if tile.opensInApp {
      Link(destination: tileUrl(host: "open", moduleId: tile.moduleId)) {
        content
      }
    } else if #available(iOSApplicationExtension 17.0, *) {
      Button(
        intent: BackgroundIntent(
          url: tileUrl(host: "quickLog", moduleId: tile.moduleId),
          appGroup: appGroupId
        )
      ) {
        content
      }
      .buttonStyle(.plain)
    } else {
      Link(destination: tileUrl(host: "quickLog", moduleId: tile.moduleId)) {
        content
      }
    }
  }

  private func tileUrl(host: String, moduleId: String) -> URL {
    var components = URLComponents()
    components.scheme = "cokloghost"
    components.host = host
    components.queryItems = [
      URLQueryItem(name: "moduleId", value: moduleId),
      URLQueryItem(name: "appGroup", value: appGroupId),
      URLQueryItem(name: "homeWidget", value: "1"),
      URLQueryItem(
        name: "t",
        value: String(Int(Date().timeIntervalSince1970 * 1000))
      ),
    ]
    return components.url!
  }
}

// MARK: - Cell chrome (Figma catalog 1:411)

enum TileProminence {
  case compact
  case regular
  case large

  var iconSize: CGFloat {
    switch self {
    case .compact: return 18
    case .regular: return 20
    case .large: return 26
    }
  }

  var actionSize: CGFloat {
    switch self {
    case .compact: return 18
    case .regular: return 20
    case .large: return 24
    }
  }

  var padding: CGFloat {
    switch self {
    case .compact: return 10
    case .regular: return 10
    case .large: return 12
    }
  }

  var titleSize: CGFloat {
    switch self {
    case .compact: return 11
    case .regular: return 11
    case .large: return 12
    }
  }

  var valueSize: CGFloat {
    switch self {
    case .compact: return 16
    case .regular: return 17
    case .large: return 19
    }
  }

  var timeSize: CGFloat {
    switch self {
    case .compact: return 10
    case .regular: return 10
    case .large: return 11
    }
  }

  var cornerRadius: CGFloat {
    switch self {
    case .compact: return 16
    case .regular: return 16
    case .large: return 18
    }
  }
}

struct WidgetCellView: View {
  let tile: CoklogTile
  let prominence: TileProminence
  var includeClock: Bool = true

  private var catalog: CoklogCategory? {
    CoklogCategories.resolve(moduleId: tile.moduleId, title: tile.title)
  }

  private var fillHex: String {
    catalog?.colorHex ?? tile.colorHex
  }

  private var opensInApp: Bool {
    catalog?.opensInApp ?? tile.opensInApp
  }

  private var displayRelative: String? {
    CoklogRelativeTime.resolveDisplayLabel(
      recordedAtMs: tile.recordedAt,
      fallback: tile.relativeLabel,
      includeClock: includeClock
    )
  }

  var body: some View {
    let pad = prominence.padding
    ZStack(alignment: .topLeading) {
      Color(hex: fillHex)

      LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
        startPoint: .topLeading,
        endPoint: UnitPoint(x: 0.85, y: 0.75)
      )

      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 4) {
          categoryIcon
            .frame(width: prominence.iconSize, height: prominence.iconSize)
          Spacer(minLength: 2)
          actionIcon
            .frame(width: prominence.actionSize, height: prominence.actionSize)
        }

        Spacer(minLength: 4)

        Text(tile.title)
          .font(.system(size: prominence.titleSize, weight: .bold))
          .foregroundStyle(Color.white.opacity(0.9))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(tile.displayValue ?? "—")
          .font(.system(size: prominence.valueSize, weight: .black))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 2)

        if let rel = displayRelative, !rel.isEmpty {
          Text(rel)
            .font(.system(size: prominence.timeSize, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
      }
      .padding(pad)
    }
    .clipShape(RoundedRectangle(cornerRadius: prominence.cornerRadius, style: .continuous))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var categoryIcon: some View {
    if let name = catalog?.assetName {
      Image(name)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
    } else {
      Image(systemName: "heart.fill")
        .font(.system(size: prominence.iconSize * 0.8, weight: .semibold))
        .foregroundStyle(.white)
    }
  }

  @ViewBuilder
  private var actionIcon: some View {
    Image(opensInApp ? "icon_launch" : "icon_plus")
      .resizable()
      .interpolation(.high)
      .scaledToFit()
  }
}

// MARK: - Widget

@main
struct CoklogHomeWidget: Widget {
  let kind: String = "CoklogHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        CoklogHomeWidgetEntryView(entry: entry)
          .containerBackground(Color.white, for: .widget)
      } else {
        CoklogHomeWidgetEntryView(entry: entry)
          .background(Color.white)
      }
    }
    .configurationDisplayName("콕로그")
    .description("육아 기록 홈 위젯")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    .contentMarginsDisabled()
  }
}
