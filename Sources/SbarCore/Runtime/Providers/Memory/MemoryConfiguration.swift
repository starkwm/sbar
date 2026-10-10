import Foundation

struct MemoryConfiguration: Codable, Equatable, Sendable {
  var symbols: AvailabilitySymbols?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
  }
}
