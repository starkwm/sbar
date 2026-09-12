import Foundation

struct MemoryState: Equatable, Sendable {
  var usedBytes: UInt64?
  var totalBytes: UInt64?

  var text: String { "RAM \(value(format: .used))" }

  var available: Bool {
    guard let usedBytes, let totalBytes else { return false }
    return totalBytes > 0 && usedBytes <= totalBytes && totalBytes <= UInt64(Int64.max)
  }

  func value(format: MemoryFormat) -> String {
    guard available, let usedBytes, let totalBytes else { return "—" }
    switch format {
    case .used:
      return ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    case .percentage:
      return "\(Int((Double(usedBytes) / Double(totalBytes) * 100).rounded()))%"
    case .usedTotal:
      let used = ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
      let total = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
      return "\(used) / \(total)"
    }
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.memory ?? MemoryConfiguration()
    let selected = available ? settings.symbols?.available : settings.symbols?.unavailable
    return WidgetPresentation(
      text: text,
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(selected)
          ?? (available ? "memorychip" : "questionmark"),
      accessibilityLabel: available
        ? "Memory usage \(value(format: .usedTotal)), \(value(format: .percentage))"
        : "Memory usage unavailable"
    )
  }
}

enum MemoryFormat: Sendable {
  case used, percentage, usedTotal
}
