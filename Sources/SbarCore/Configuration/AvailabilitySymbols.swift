import Foundation

struct AvailabilitySymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var available: WidgetSymbol?
  var unavailable: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)
    try available?.validate(font: font, path: "\(path).available")
    try unavailable?.validate(font: font, path: "\(path).unavailable")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}
