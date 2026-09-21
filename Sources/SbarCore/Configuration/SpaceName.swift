import Foundation

enum SpaceName: Codable, Equatable, Sendable, ExpressibleByStringLiteral {
  case text(String)
  case symbol(ItemSymbol)

  private enum CodingKeys: String, CodingKey { case symbol }

  init(stringLiteral value: String) {
    self = .text(value)
  }

  init(from decoder: any Decoder) throws {
    if let text = try? decoder.singleValueContainer().decode(String.self) {
      self = .text(text)

      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let symbol = try container.decode(ItemSymbol.self, forKey: .symbol)

    if case .system(let name) = symbol,
      name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      throw DecodingError.dataCorruptedError(
        forKey: .symbol,
        in: container,
        debugDescription: "Symbol name must not be blank."
      )
    }

    self = .symbol(symbol)
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case .text(let text):
      var container = encoder.singleValueContainer()
      try container.encode(text)
    case .symbol(let symbol):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(symbol, forKey: .symbol)
    }
  }
}
