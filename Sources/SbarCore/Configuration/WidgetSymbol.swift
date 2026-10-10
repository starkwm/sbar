import Foundation

enum WidgetSymbol: Codable, Equatable, Sendable {
  case system(String)
  case glyph(String, font: String? = nil, size: Double? = nil)

  private enum CodingKeys: String, CodingKey { case glyph, font, size }

  static func validateDefaults(font: String?, size: Double?, path: String) throws {
    if let font, font.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ConfigurationError.invalidValue(path: "\(path).font", reason: "Must not be blank.")
    }
    if let size, !(8...72).contains(size) {
      throw ConfigurationError.invalidValue(
        path: "\(path).size",
        reason: "Must be between 8 and 72."
      )
    }
  }

  init(from decoder: any Decoder) throws {
    if let name = try? decoder.singleValueContainer().decode(String.self) {
      self = .system(name)

      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    self = .glyph(
      try container.decode(String.self, forKey: .glyph),
      font: try container.decodeIfPresent(String.self, forKey: .font),
      size: try container.decodeIfPresent(Double.self, forKey: .size)
    )
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case .system(let name):
      var container = encoder.singleValueContainer()
      try container.encode(name)
    case .glyph(let glyph, let font, let size):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(glyph, forKey: .glyph)
      try container.encodeIfPresent(font, forKey: .font)
      try container.encodeIfPresent(size, forKey: .size)
    }
  }

  func validate(font inheritedFont: String?, path: String) throws {
    guard case .glyph(let glyph, let font, let size) = self else { return }
    guard !glyph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let resolvedFont = font ?? inheritedFont,
      !resolvedFont.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      size.map({ (8...72).contains($0) }) ?? true
    else {
      throw ConfigurationError.invalidValue(
        path: path,
        reason:
          "Glyph must not be blank, a font must be provided or inherited, and size must be between 8 and 72."
      )
    }
  }

  func resolve(font inheritedFont: String?, size inheritedSize: Double?) -> ItemSymbol? {
    switch self {
    case .system(let name):
      return .system(name)
    case .glyph(let glyph, let font, let size):
      guard let font = font ?? inheritedFont else { return nil }

      return .glyph(glyph, font: font, size: size ?? inheritedSize)
    }
  }
}
