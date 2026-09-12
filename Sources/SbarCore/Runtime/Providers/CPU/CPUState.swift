struct CPUState: Equatable, Sendable {
  var samples: [Double] = []

  var text: String {
    percentage(smoothingSamples: 1).map { "CPU \($0)%" } ?? "CPU —"
  }

  func percentage(smoothingSamples: Int) -> Int? {
    let values = samples.suffix(min(30, max(1, smoothingSamples)))
    guard !values.isEmpty else { return nil }
    return Int((values.reduce(0, +) / Double(values.count)).rounded())
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.cpu ?? CPUConfiguration()
    let percentage = percentage(smoothingSamples: settings.smoothingSamples ?? 1)
    let selected: WidgetSymbol?
    let tint: String?
    if let percentage {
      if percentage >= (settings.highThreshold ?? 85) {
        selected = settings.symbols?.high
        tint = settings.tints?.high
      } else if percentage >= (settings.warningThreshold ?? 60) {
        selected = settings.symbols?.medium
        tint = settings.tints?.medium
      } else {
        selected = settings.symbols?.low
        tint = settings.tints?.low
      }
    } else {
      selected = settings.symbols?.unavailable
      tint = settings.tints?.unavailable
    }
    let parts: [String?] = [
      settings.showLabel == false ? nil : "CPU",
      settings.showPercentage == false ? nil : percentage.map { "\($0)%" } ?? "—",
    ]
    return WidgetPresentation(
      text: parts.compactMap { $0 }.joined(separator: " "),
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(selected)
          ?? (percentage == nil ? "questionmark" : "cpu"),
      tint: tint,
      accessibilityLabel: percentage.map { "CPU usage \($0) percent" } ?? "CPU usage unavailable",
      tooltipValues: [
        "percentage": percentage.map(String.init) ?? "",
        "status": percentage == nil ? "unavailable" : "available",
      ]
    )
  }
}
