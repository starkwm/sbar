import Foundation

struct ThroughputState: Equatable, Sendable {
  static func format(_ bytesPerSecond: Double, unit: ThroughputUnit, showUnits: Bool = true)
    -> String
  {
    let base: Double = unit == .bytes ? 1024 : 1000
    let units =
      unit == .bytes
      ? ["B/s", "KiB/s", "MiB/s", "GiB/s"] : ["bit/s", "kbit/s", "Mbit/s", "Gbit/s"]
    var value = bytesPerSecond * (unit == .bits ? 8 : 1)
    var index = 0
    while value >= base && index < units.count - 1 {
      value /= base
      index += 1
    }
    var rounded = (value * 10).rounded() / 10
    if rounded >= base && index < units.count - 1 {
      index += 1
      rounded = (rounded / base * 10).rounded() / 10
    }
    let number = String(
      format: rounded == rounded.rounded() ? "%.0f" : "%.1f",
      locale: Locale(identifier: "en_US_POSIX"),
      rounded
    )
    return showUnits ? "\(number) \(units[index])" : number
  }

  var histories: [String: [ThroughputRate]] = [:]

  var text: String {
    guard let rate = rate(interfaces: nil, smoothingSamples: 1) else { return "Throughput —" }
    return "↓\(Self.format(rate.download, unit: .bytes)) ↑\(Self.format(rate.upload, unit: .bytes))"
  }

  func rate(interfaces: [String]?, smoothingSamples: Int) -> ThroughputRate? {
    let selected = interfaces ?? histories.keys.sorted().filter { histories[$0]?.isEmpty == false }
    guard !selected.isEmpty else { return nil }
    var total = ThroughputRate(download: 0, upload: 0)
    for name in selected {
      guard let history = histories[name], !history.isEmpty else { return nil }
      let samples = history.suffix(min(30, max(1, smoothingSamples)))
      total.download += samples.reduce(0) { $0 + $1.download } / Double(samples.count)
      total.upload += samples.reduce(0) { $0 + $1.upload } / Double(samples.count)
    }
    return total
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.throughput ?? ThroughputConfiguration()
    let showSymbol = settings.showSymbol != false
    guard
      let rate = rate(
        interfaces: settings.interfaces,
        smoothingSamples: settings.smoothingSamples ?? 1
      )
    else {
      return WidgetPresentation(
        text: settings.showValue == false ? "" : "—",
        symbol: showSymbol
          ? item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
            ?? "questionmark" : nil,
        accessibilityLabel: "Network throughput unavailable"
      )
    }
    var segments: [WidgetSegment] = []
    var labels: [String] = []
    for (enabled, value, name, selected, fallback) in [
      (
        settings.showDownload != false, rate.download, "Download", settings.symbols?.download,
        "arrow.down"
      ),
      (settings.showUpload != false, rate.upload, "Upload", settings.symbols?.upload, "arrow.up"),
    ] where enabled {
      let formatted = Self.format(value, unit: settings.unit ?? .bytes)
      labels.append("\(name) \(formatted)")
      segments.append(
        WidgetSegment(
          text: settings.showValue == false
            ? ""
            : Self.format(
              value,
              unit: settings.unit ?? .bytes,
              showUnits: settings.showUnits != false
            ),
          symbol: showSymbol && item.symbol == nil
            ? settings.symbols?.resolve(selected) ?? .system(fallback) : nil
        )
      )
    }
    segments = segments.filter { !$0.text.isEmpty || $0.symbol != nil }
    return WidgetPresentation(
      text: segments.map(\.text).filter { !$0.isEmpty }.joined(separator: " "),
      symbol: showSymbol ? item.symbol : nil,
      segments: segments,
      accessibilityLabel: labels.isEmpty ? "Network throughput" : labels.joined(separator: ", ")
    )
  }
}

struct ThroughputRate: Equatable, Sendable {
  var download: Double
  var upload: Double
}
