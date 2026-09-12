import Foundation

struct TooltipTemplate {
  private enum Part {
    case literal(String)
    case token(String)
  }

  static func tokens(for type: ItemType) -> Set<String> {
    let provider: Set<String>

    switch type {
    case .battery, .volume, .cpu: provider = ["percentage", "status"]
    case .memory: provider = ["used", "total", "percentage", "status"]
    case .disk: provider = ["free", "used", "total", "percentage", "path", "status"]
    case .throughput: provider = ["download", "upload", "status"]
    case .media: provider = ["title", "artist", "source", "status"]
    case .vpn, .bluetooth: provider = ["names", "count", "status"]
    case .audioDevice: provider = ["name", "device", "status"]
    case .network: provider = ["interface", "status"]
    case .aerospace: provider = ["workspace", "workspaces", "count"]
    case .yabai, .spaces: provider = ["workspace", "workspaces", "index", "count"]
    case .command, .plugin: provider = ["output", "status", "error"]
    case .frontApplication: provider = ["name"]
    case .datetime, .text, .group, .popup, .divider, .spacer: provider = []
    }

    return provider.union(["id", "label", "text", "summary"])
  }

  private var parts: [Part] = []

  init(_ source: String, type: ItemType, path: String = "tooltip") throws {
    let allowed = Self.tokens(for: type)
    let characters = Array(source)

    var index = 0
    var literal = ""

    while index < characters.count {
      let character = characters[index]

      if character == "{" || character == "}" {
        if index + 1 < characters.count, characters[index + 1] == character {
          literal.append(character)
          index += 2
          continue
        }

        guard character == "{" else {
          throw ConfigurationError.invalidValue(
            path: path,
            reason: "Unmatched '}'. Use '}}' for a literal brace."
          )
        }

        parts.append(.literal(literal))
        literal = ""
        index += 1

        var token = ""

        while index < characters.count, characters[index] != "}", characters[index] != "{" {
          token.append(characters[index])
          index += 1
        }

        guard index < characters.count, characters[index] == "}" else {
          throw ConfigurationError.invalidValue(
            path: path,
            reason: "Unclosed token. Use '{{' for a literal brace."
          )
        }

        guard allowed.contains(token) else {
          throw ConfigurationError.invalidValue(
            path: path,
            reason:
              "Unknown token '{\(token)}' for \(type.rawValue). Supported tokens: \(allowed.sorted().joined(separator: ", "))."
          )
        }

        parts.append(.token(token))
      } else {
        literal.append(character)
      }

      index += 1
    }

    parts.append(.literal(literal))
  }

  func render(values: [String: String]) -> String {
    parts.map { part in
      switch part {
      case .literal(let text): return text
      case .token(let name):
        guard let value = values[name],
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return "—" }

        return value
      }
    }.joined()
  }
}
