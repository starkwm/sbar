import Foundation

struct MediaConfiguration: Codable, Equatable, Sendable {
  var source: MediaSourceSelection?
  var symbols: MediaSymbols?
  var showSymbol: Bool?
  var hideWhenPaused: Bool?
  var hideWhenStopped: Bool?
  var hideWhenNotPlaying: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
  }
}

enum MediaSourceSelection: String, Codable, Sendable {
  case automatic, music, spotify
}

struct MediaSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var playing: WidgetSymbol?
  var paused: WidgetSymbol?
  var stopped: WidgetSymbol?
  var unavailable: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)
    for (key, symbol) in [
      ("playing", playing), ("paused", paused), ("stopped", stopped), ("unavailable", unavailable),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}
