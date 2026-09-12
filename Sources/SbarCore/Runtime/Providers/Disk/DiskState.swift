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
    return WidgetPresentation(
      text: available ? "\(value(format: .free)) free" : "— unavailable",
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(
          available ? settings.symbols?.available : settings.symbols?.unavailable
        )
          ?? (available ? "internaldrive" : "questionmark"),
      tint: tint,
      accessibilityLabel: available
        ? "Disk \(settings.resolvedPath), \(value(format: .free)) free, \(value(format: .total)) total, \(value(format: .percentage)) used"
        : "Disk \(settings.resolvedPath) unavailable"
    )
  }
}

enum DiskFormat: Sendable {
  case free, used, total, usedTotal, percentage
}
