import Foundation

struct TextTemplate {
  indirect enum Part {
    case literal(String)
    case value(String)
    case section(String, equals: String?, inverted: Bool, [Part])
  }

  struct Run {
    var text: String
    var entry: Int?
    var separator = false
  }

  private static let collections: Set<String> = ["workspaces", "services", "devices"]

  static func fields(for type: ItemType) -> Set<String> {
    let common: Set<String> = ["value", "id"]
    let fields: [String]
    switch type {
    case .spaces, .aerospace, .yabai:
      fields = [
        "workspaces", "separator", "name", "index", "workspaceId", "total", "active", "focused",
        "visible",
        "fullscreen", "available", "first", "last",
      ]
    case .cpu: fields = ["percentage", "available"]
    case .battery: fields = ["percentage", "charging", "pluggedIn", "available", "status"]
    case .volume: fields = ["percentage", "muted", "available", "status"]
    case .memory: fields = ["used", "total", "percentage", "usedBytes", "totalBytes", "available"]
    case .disk:
      fields = ["used", "free", "total", "percentage", "freeBytes", "totalBytes", "available"]
    case .media: fields = ["title", "artist", "source", "status", "playing", "available"]
    case .mail: fields = ["unreadCount", "status", "available"]
    case .throughput: fields = ["download", "upload", "available"]
    case .network: fields = ["status", "connected"]
    case .vpn:
      fields = [
        "status", "names", "connected", "available", "services", "name", "serviceId", "index",
        "total", "first", "last", "separator",
      ]
    case .bluetooth:
      fields = [
        "status", "names", "count", "connected", "devices", "name", "deviceId", "index", "total",
        "first", "last", "separator",
      ]
    case .audioDevice: fields = ["name", "status", "available"]
    case .frontApplication: fields = ["name"]
    case .command, .plugin: fields = ["status", "error"]
    default: fields = []
    }
    return common.union(fields)
  }

  static func allowedValues(for type: ItemType) -> [String: Set<String>] {
    let statuses: Set<String>
    switch type {
    case .battery: statuses = ["charging", "pluggedIn", "onBattery", "noBattery"]
    case .volume: statuses = ["available", "muted", "fixed", "unavailable"]
    case .network: statuses = Set(NetworkConnection.allCases.map(\.rawValue))
    case .vpn: statuses = Set(VPNStatus.allCases.map(\.rawValue))
    case .bluetooth: statuses = Set(BluetoothStatus.allCases.map(\.rawValue))
    case .audioDevice: statuses = Set(AudioDeviceStatus.allCases.map(\.rawValue))
    case .media: statuses = ["playing", "paused", "stopped", "unknown"]
    case .mail: statuses = ["available", "closed", "unauthorized", "unavailable"]
    case .command, .plugin: statuses = ["running", "success", "failure"]
    default: statuses = []
    }
    var values: [String: Set<String>] = [:]
    if !statuses.isEmpty { values["status"] = statuses }
    for name in fields(for: type).intersection([
      "available", "charging", "pluggedIn", "muted", "playing", "connected",
      "active", "focused", "visible", "fullscreen", "first", "last",
    ]) {
      values[name] = ["true", "false"]
    }
    if type == .media { values["source"] = ["Music", "Spotify"] }
    return values
  }

  private let parts: [Part]

  init(
    _ source: String,
    fields: Set<String>,
    allowedValues: [String: Set<String>] = [:],
    path: String = "text"
  ) throws {
    var remaining = source[...]
    func fail(_ reason: String) -> ConfigurationError {
      .invalidValue(path: path, reason: reason)
    }
    func parse(closing: String? = nil, depth: Int = 0, inCollection: Bool = false) throws -> [Part]
    {
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
        let expression = section ? String(tag.dropFirst()) : tag
        let components =
          section
          ? expression.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(
            String.init
          ) : [expression]
        let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let expected =
          components.count == 2
          ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        guard fields.contains(name) else { throw fail("Unknown text template value '\(name)'.") }
        if name == "separator" {
          guard section, expected == nil, !tag.hasPrefix("^"), inCollection else {
            throw fail("Use {{#separator}}...{{/separator}} inside a collection loop.")
          }
        }
        if Self.collections.contains(name) {
          guard section, expected == nil, !inCollection else {
            throw fail(
              "Use collections as sections without a comparison. Collection sections cannot nest."
            )
          }
        }
        if let expected {
          guard !expected.isEmpty else { throw fail("An equality condition needs a value.") }
          if let allowed = allowedValues[name], !allowed.contains(expected) {
            throw fail(
              "Unknown value '\(expected)' for '\(name)'. Expected one of: \(allowed.sorted().joined(separator: ", "))."
            )
          }
        }
        if section {
          result.append(
            .section(
              name,
              equals: expected,
              inverted: tag.hasPrefix("^"),
              try parse(
                closing: name,
                depth: depth + 1,
                inCollection: inCollection || Self.collections.contains(name)
              )
            )
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
    renderRuns(values).map(\.text).joined()
  }

  func renderRuns(_ values: [String: String], entries: [[String: String]] = []) -> [Run] {
    var runs: [Run] = []
    func append(_ text: String, entry: Int?, separator: Bool) {
      guard !text.isEmpty else { return }
      if let last = runs.indices.last, runs[last].entry == entry, runs[last].separator == separator
      {
        runs[last].text += text
      } else {
        runs.append(Run(text: text, entry: entry, separator: separator))
      }
    }
    func render(
      _ parts: [Part],
      values: [String: String],
      entry: Int? = nil,
      separator: Bool = false
    ) {
      for part in parts {
        switch part {
        case .literal(let text): append(text, entry: entry, separator: separator)
        case .value(let name): append(values[name] ?? "", entry: entry, separator: separator)
        case .section(let name, let expected, let inverted, let children):
          if name == "separator" {
            if let entry, entry < entries.count - 1 {
              render(children, values: values, entry: entry, separator: true)
            }
          } else if Self.collections.contains(name) {
            if inverted {
              if entries.isEmpty {
                render(children, values: values, entry: entry, separator: separator)
              }
            } else {
              for (index, fields) in entries.enumerated() {
                var local = values.merging(fields) { _, value in value }
                local["first"] = String(index == 0)
                local["last"] = String(index == entries.count - 1)
                render(children, values: local, entry: index)
              }
            }
          } else {
            let value = values[name] ?? ""
            let present =
              expected.map { values[name] == $0 } ?? (!value.isEmpty && value != "false")
            if present != inverted {
              render(children, values: values, entry: entry, separator: separator)
            }
          }
        }
      }
    }
    render(parts, values: values)
    return runs
  }
}
