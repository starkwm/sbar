import Foundation

struct MemoryConfiguration: Codable, Equatable, Sendable {
  var format: MemoryFormat?
  var symbols: MemorySymbols?
  var showLabel: Bool?
  var showValue: Bool?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
  }
}

enum MemoryFormat: String, Codable, Sendable {
  case used, percentage, usedTotal
}

struct MemorySymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var available: WidgetSymbol?
  var unavailable: WidgetSymbol?

  func validate(path: String) throws {
    if let font, font.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ConfigurationError.invalidValue(path: "\(path).font", reason: "Must not be blank.")
    }
    if let size, !(8...72).contains(size) {
      throw ConfigurationError.invalidValue(
        path: "\(path).size",
        reason: "Must be between 8 and 72."
      )
    }
    try available?.validate(font: font, path: "\(path).available")
    try unavailable?.validate(font: font, path: "\(path).unavailable")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}
