import Foundation

struct PluginOutputFramer {
  private var pending = Data()

  mutating func append(_ data: Data) throws -> PluginOutput? {
    pending.append(data)
    var latest: PluginOutput?

    while let newline = pending.firstIndex(of: 10) {
      let line = pending.prefix(upTo: newline)
      guard line.count <= 65_536 else { throw PluginProtocolError.lineLimit }
      guard let text = String(data: line, encoding: .utf8) else {
        throw PluginProtocolError.invalidMessage
      }

      do {
        latest = try CommandState.decode(
          text,
          configuration: ShellCommand(script: "plugin", format: .json)
        )
      } catch { throw PluginProtocolError.invalidMessage }

      pending.removeSubrange(...newline)
    }

    guard pending.count <= 65_536 else { throw PluginProtocolError.lineLimit }

    return latest
  }

  func finish() throws {
    if !pending.isEmpty { throw PluginProtocolError.unterminatedMessage }
  }
}

enum PluginProtocolError: Error, LocalizedError {
  case lineLimit, invalidMessage, unterminatedMessage

  var errorDescription: String? {
    switch self {
    case .lineLimit: "Plugin output line exceeded 64 KB."
    case .invalidMessage: "Plugin emitted an invalid JSON message."
    case .unterminatedMessage: "Plugin output ended without a newline."
    }
  }
}
