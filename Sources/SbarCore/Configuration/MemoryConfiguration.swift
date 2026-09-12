import Foundation

struct MemoryConfiguration: Codable, Equatable, Sendable {
  var format: MemoryFormat?
  var symbols: AvailabilitySymbols?
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
