import Foundation

struct ThroughputState: Equatable, Sendable {
  static func format(_ bytesPerSecond: Double, unit: ThroughputUnit)
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
    return "\(number) \(units[index])"
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
    let rate = rate(
      interfaces: settings.interfaces,
      smoothingSamples: settings.smoothingSamples ?? 1
    )
    let entries: [[String: String]] =
      rate.map { rate in
        [("download", rate.download), ("upload", rate.upload)].enumerated().map { index, transfer in
          let formatted = Self.format(transfer.1, unit: settings.unit ?? .bytes)
          let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
          return [
            "direction": transfer.0, "value": formatted, "number": parts[0], "unit": parts[1],
            "index": String(index + 1),
          ]
        }
      } ?? []
    var values = [
      "id": item.id, "available": String(rate != nil), "total": String(entries.count),
      "value": entries.isEmpty ? "—" : entries.map { $0["value"]! }.joined(separator: " "),
    ]
    for entry in entries {
      let direction = entry["direction"]!
      values[direction] = entry["value"]
      values["\(direction).value"] = entry["number"]
      values["\(direction).unit"] = entry["unit"]
    }
    let source =
      item.text
      ?? "{{#transfers}}{{symbol}}{{value}}{{/transfers}}{{^transfers}}{{value}}{{/transfers}}"
    let template = try? TextTemplate(
      source,
      fields: TextTemplate.fields(for: .throughput),
      allowedValues: TextTemplate.allowedValues(for: .throughput)
    )
    let runs = template?.renderRuns(values, entries: entries) ?? []
    let segments = runs.map { run in
      let download = run.entry == 0
      return WidgetSegment(
        text: run.text,
        symbol: run.symbol && run.entry != nil && showSymbol && item.symbol == nil
          ? settings.symbols?.resolve(
            download ? settings.symbols?.download : settings.symbols?.upload
          ) ?? .system(download ? "arrow.down" : "arrow.up") : nil
      )
    }.filter { !$0.text.isEmpty || $0.symbol != nil }
    return WidgetPresentation(
      text: runs.map(\.text).joined(separator: item.text == nil ? " " : ""),
      symbol: showSymbol
        && (template?.containsSymbol != true || runs.contains(where: \.symbol) || item.text == nil)
        ? item.symbol
          ?? (rate == nil
            ? settings.symbols?.resolve(settings.symbols?.unavailable) ?? "questionmark" : nil)
        : nil,
      segments: runs.contains { $0.entry != nil } ? segments : [],
      accessibilityLabel: entries.isEmpty
        ? "Network throughput unavailable"
        : entries.map { "\($0["direction"]!.capitalized) \($0["value"]!)" }.joined(separator: ", "),
      segmentSpacing: item.text == nil ? 4 : 0
    )
  }
}

struct ThroughputRate: Equatable, Sendable {
  var download: Double
  var upload: Double
}
