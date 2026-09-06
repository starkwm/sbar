import Foundation

enum ItemSymbol: Codable, Equatable, Sendable, ExpressibleByStringLiteral {
  case network([String: WidgetSymbol])
  case system(String)
  case glyph(String, font: String, size: Double? = nil)

  private enum CodingKeys: String, CodingKey { case glyph, font, size }

  init(stringLiteral value: String) {
    self = .system(value)
  }

  init(from decoder: any Decoder) throws {
    if let name = try? decoder.singleValueContainer().decode(String.self) {
      self = .system(name)
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if !container.contains(.glyph) && !container.contains(.font) && !container.contains(.size) {
      let symbols = try decoder.singleValueContainer().decode([String: WidgetSymbol].self)
      for (key, symbol) in symbols {
        guard NetworkConnection(rawValue: key) != nil else {
          throw DecodingError.dataCorrupted(
            .init(
              codingPath: decoder.codingPath,
              debugDescription: "Unknown network symbol key: \(key)"
            )
          )
        }
        try symbol.validate(font: nil, path: "symbol.\(key)")
      }
      self = .network(symbols)
      return
    }
    let glyph = try container.decode(String.self, forKey: .glyph)
    let font = try container.decode(String.self, forKey: .font)
    let size = try container.decodeIfPresent(Double.self, forKey: .size)
    guard !glyph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !font.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      size.map { (8...72).contains($0) } ?? true
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Glyph and font must not be blank; size must be between 8 and 72."
        )
      )
    }
    self = .glyph(glyph, font: font, size: size)
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case .network(let symbols):
      var container = encoder.singleValueContainer()
      try container.encode(symbols)
    case .system(let name):
      var container = encoder.singleValueContainer()
      try container.encode(name)
    case .glyph(let glyph, let font, let size):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(glyph, forKey: .glyph)
      try container.encode(font, forKey: .font)
      try container.encodeIfPresent(size, forKey: .size)
    }
  }
}
