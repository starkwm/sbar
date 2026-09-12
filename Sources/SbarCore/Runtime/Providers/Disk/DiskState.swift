import Foundation

struct DiskState: Equatable, Sendable {
  var freeBytes: Int64?
  var totalBytes: Int64?

  var available: Bool {
    guard let freeBytes, let totalBytes else { return false }
    return totalBytes > 0 && freeBytes >= 0 && freeBytes <= totalBytes
  }

  var text: String { available ? "\(value(format: .free)) free" : "Disk —" }

  var freePercentage: Double? {
    guard available, let freeBytes, let totalBytes else { return nil }
    return Double(freeBytes) / Double(totalBytes) * 100
  }

  func value(format: DiskFormat) -> String {
    guard available, let freeBytes, let totalBytes else { return "—" }
    let used = totalBytes - freeBytes
    switch format {
    case .free: return ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    case .used: return ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    case .total: return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    case .usedTotal:
      return
        "\(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
    case .percentage: return "\(Int((Double(used) / Double(totalBytes) * 100).rounded()))%"
    }
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.disk ?? DiskConfiguration()
    let format = settings.format ?? .free
    let label: String
    switch format {
    case .free: label = "free"
    case .used, .usedTotal, .percentage: label = "used"
    case .total: label = "total"
    }
    let tint: String?
    if let free = freePercentage {
      tint =
        free <= Double(settings.criticalThreshold ?? 10)
        ? settings.tints?.critical
        : free <= Double(settings.warningThreshold ?? 20)
          ? settings.tints?.warning : settings.tints?.normal
    } else {
      tint = settings.tints?.unavailable
    }
    let parts: [String?] = [
      settings.showValue == false ? nil : value(format: format),
      settings.showLabel == false ? nil : available ? label : "unavailable",
    ]
    return WidgetPresentation(
      text: parts.compactMap { $0 }.joined(separator: " "),
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(
          available ? settings.symbols?.available : settings.symbols?.unavailable
        )
          ?? (available ? "internaldrive" : "questionmark"),
      tint: tint,
      accessibilityLabel: available
        ? "Disk \(settings.resolvedPath), \(value(format: .free)) free, \(value(format: .total)) total, \(value(format: .percentage)) used"
        : "Disk \(settings.resolvedPath) unavailable",
      tooltipValues: [
        "free": value(format: .free),
        "used": value(format: .used),
        "total": value(format: .total),
        "percentage": available ? String(value(format: .percentage).dropLast()) : "",
        "path": settings.resolvedPath,
        "status": available ? "available" : "unavailable",
      ]
    )
  }
}
