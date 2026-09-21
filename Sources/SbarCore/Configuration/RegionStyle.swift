import Foundation

struct RegionStyle: Codable, Equatable, Sendable {
  var background: String?
  var cornerRadius: Double?
  var horizontalPadding: Double?
  var verticalPadding: Double?
  var borderColor: String?
  var borderWidth: Double?
  var itemSpacing: Double?

  func resolved(over defaults: RegionStyle?) -> RegionStyle {
    RegionStyle(
      background: background ?? defaults?.background,
      cornerRadius: cornerRadius ?? defaults?.cornerRadius,
      horizontalPadding: horizontalPadding ?? defaults?.horizontalPadding,
      verticalPadding: verticalPadding ?? defaults?.verticalPadding,
      borderColor: borderColor ?? defaults?.borderColor,
      borderWidth: borderWidth ?? defaults?.borderWidth,
      itemSpacing: itemSpacing ?? defaults?.itemSpacing
    )
  }

  func validate(path: String) throws {
    try ItemStyle.validateColor(background, path: "\(path).background")
    try ItemStyle.validateColor(borderColor, path: "\(path).borderColor")

    for (name, value, maximum) in [
      ("cornerRadius", cornerRadius, 48.0),
      ("horizontalPadding", horizontalPadding, 96.0),
      ("verticalPadding", verticalPadding, 48.0),
      ("borderWidth", borderWidth, 48.0),
      ("itemSpacing", itemSpacing, 96.0),
    ] {
      try ItemStyle.validateNumber(value, range: 0...maximum, path: "\(path).\(name)")
    }
  }
}

struct RegionStyles: Codable, Equatable, Sendable {
  var left: RegionStyle?
  var center: RegionStyle?
  var right: RegionStyle?

  func validate() throws {
    try left?.validate(path: "theme.regions.left")
    try center?.validate(path: "theme.regions.center")
    try right?.validate(path: "theme.regions.right")
  }
}
