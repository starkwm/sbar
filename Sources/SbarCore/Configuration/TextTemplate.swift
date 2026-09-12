import Foundation

struct TextTemplate {
  indirect enum Part {
    case literal(String)
    case value(String)
    case section(String, inverted: Bool, [Part])
  }

  static func fields(for type: ItemType) -> Set<String> {
    let common: Set<String> = ["value", "id"]
    let fields: [String]
    switch type {
    case .cpu: fields = ["percentage", "available"]
    case .battery: fields = ["percentage", "charging", "pluggedIn", "available"]
    case .volume: fields = ["percentage", "muted", "available"]
    case .memory: fields = ["used", "total", "percentage", "usedBytes", "totalBytes", "available"]
    case .disk:
      fields = ["used", "free", "total", "percentage", "freeBytes", "totalBytes", "available"]
    case .media: fields = ["title", "artist", "source", "status", "playing", "available"]
    case .mail: fields = ["unreadCount", "status", "available"]
    case .throughput: fields = ["download", "upload", "available"]
    case .network: fields = ["status", "connected"]
    case .vpn: fields = ["status", "names", "connected", "available"]
    case .bluetooth: fields = ["status", "names", "count", "connected"]
    case .audioDevice: fields = ["name", "status", "available"]
    case .frontApplication: fields = ["name"]
    case .command, .plugin: fields = ["status", "error"]
    default: fields = []
    }
    return common.union(fields)
  }

  private let parts: [Part]

  init(_ source: String, fields: Set<String>, path: String = "text") throws {
    var remaining = source[...]
    func fail(_ reason: String) -> ConfigurationError {
      .invalidValue(path: path, reason: reason)
    }
    func parse(closing: String? = nil, depth: Int = 0) throws -> [Part] {
      guard depth <= 8 else { throw fail("Text sections may nest at most eight levels.") }
      var result: [Part] = []
      while let start = remaining.range(of: "{{") {
        result.append(.literal(String(remaining[..<start.lowerBound])))
        remaining = remaining[start.upperBound...]
        guard let end = remaining.range(of: "}}") else {
          throw fail("Unclosed text template tag.")
        }
        let tag = remaining[..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        remaining = remaining[end.upperBound...]
        if tag.hasPrefix("/") {
          guard String(tag.dropFirst()) == closing else {
            throw fail("Unexpected closing tag '\(tag)'.")
          }
          return result
        }
        let section = tag.hasPrefix("#") || tag.hasPrefix("^")
        let name = section ? String(tag.dropFirst()) : tag
        guard fields.contains(name) else { throw fail("Unknown text template value '\(name)'.") }
        if section {
          result.append(
            .section(name, inverted: tag.hasPrefix("^"), try parse(closing: name, depth: depth + 1))
          )
        } else {
          result.append(.value(name))
        }
      }
      guard closing == nil else { throw fail("Unclosed text section '\(closing!)'.") }
      result.append(.literal(String(remaining)))
      remaining = ""[...]
      return result
    }
    parts = try parse()
  }

  func render(_ values: [String: String]) -> String {
    func render(_ parts: [Part]) -> String {
      parts.map { part in
        switch part {
        case .literal(let text): return text
        case .value(let name): return values[name] ?? ""
        case .section(let name, let inverted, let children):
          let value = values[name] ?? ""
          let present = !value.isEmpty && value != "false"
          return present != inverted ? render(children) : ""
        }
      }.joined()
    }
    return render(parts)
  }
}
