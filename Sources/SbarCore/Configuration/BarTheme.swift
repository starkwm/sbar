import Foundation

struct BarTheme: Codable, Equatable, Sendable {
  var background: String?
  var horizontalPadding: Double?
  var itemSpacing: Double?
  var itemStyle: ItemStyle?

  func validate() throws {
    try ItemStyle.validateColor(background, path: "theme.background")
    try ItemStyle.validateNumber(horizontalPadding, range: 0...96, path: "theme.horizontalPadding")
    try ItemStyle.validateNumber(itemSpacing, range: 0...96, path: "theme.itemSpacing")
    try itemStyle?.validate(path: "theme.itemStyle")
  }
}

struct ItemStyle: Codable, Equatable, Sendable {
  static func validateColor(_ value: String?, path: String) throws {
    if let value, RGBA(hex: value) == nil {
      throw ConfigurationError.invalidValue(path: path, reason: "Use #RRGGBB or #RRGGBBAA.")
    }
  }

  static func validateNumber(_ value: Double?, range: ClosedRange<Double>, path: String) throws {
    if let value, !range.contains(value) {
      throw ConfigurationError.invalidValue(
        path: path,
        reason: "Must be between \(range.lowerBound) and \(range.upperBound)."
      )
    }
  }

  var tint: String?
  var background: String?

  var fontSize: Double?
  var fontWeight: ItemFontWeight?

  var horizontalPadding: Double?
  var verticalPadding: Double?
  var cornerRadius: Double?

  func resolved(over theme: ItemStyle?) -> ItemStyle {
    ItemStyle(
      tint: tint ?? theme?.tint,
      background: background ?? theme?.background,
      fontSize: fontSize ?? theme?.fontSize ?? 13,
      fontWeight: fontWeight ?? theme?.fontWeight ?? .regular,
      horizontalPadding: horizontalPadding ?? theme?.horizontalPadding ?? 0,
      verticalPadding: verticalPadding ?? theme?.verticalPadding ?? 0,
      cornerRadius: cornerRadius ?? theme?.cornerRadius ?? 0
    )
  }

  func validate(path: String) throws {
    try Self.validateColor(tint, path: "\(path).tint")
    try Self.validateColor(background, path: "\(path).background")

    try Self.validateNumber(fontSize, range: 8...72, path: "\(path).fontSize")
    try Self.validateNumber(horizontalPadding, range: 0...96, path: "\(path).horizontalPadding")
    try Self.validateNumber(verticalPadding, range: 0...48, path: "\(path).verticalPadding")
    try Self.validateNumber(cornerRadius, range: 0...48, path: "\(path).cornerRadius")
  }
}

enum ItemFontWeight: String, Codable, CaseIterable, Sendable {
  case regular, medium, semibold, bold
}

struct RGBA: Equatable, Sendable {
  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  init?(hex: String) {
    guard hex.first == "#", hex.count == 7 || hex.count == 9 else { return nil }

    let digits = hex.dropFirst()
    guard digits.allSatisfy({ $0.isASCII && $0.isHexDigit }), let value = UInt32(digits, radix: 16)
    else { return nil }

    let rgba = hex.count == 7 ? (value << 8) | 255 : value
    red = Double((rgba >> 24) & 255) / 255
    green = Double((rgba >> 16) & 255) / 255
    blue = Double((rgba >> 8) & 255) / 255
    alpha = Double(rgba & 255) / 255
  }
}
