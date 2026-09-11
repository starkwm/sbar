import Foundation

struct AudioDeviceState: Equatable, Sendable {
  var output = AudioDeviceEndpoint()
  var input = AudioDeviceEndpoint()

  var text: String { presentation(for: Item(id: "audioDevice", type: .audioDevice)).text }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.audioDevice ?? AudioDeviceConfiguration()
    let kind = settings.device ?? .output
    let endpoint = kind == .input ? input : output
    let name = endpoint.name?.split(whereSeparator: \.isWhitespace).joined(separator: " ") ?? ""
    let label: String
    switch endpoint.status {
    case .available: label = name.isEmpty ? "Unnamed device" : name
    case .disconnected: label = "No \(kind.rawValue)"
    case .unavailable: label = "\(kind.label) unavailable"
    }
    return WidgetPresentation(
      text: settings.showLabel == false ? "" : settings.labels?[endpoint.status.rawValue] ?? label,
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(endpoint.status, device: kind)
          ?? endpoint.status.defaultSymbol(for: kind),
      tint: settings.tints?[endpoint.status.rawValue],
      hidden: endpoint.status == .disconnected && settings.hideWhenDisconnected == true,
      accessibilityLabel: endpoint.status == .available ? "\(kind.label): \(label)" : label
    )
  }
}

struct AudioDeviceEndpoint: Equatable, Sendable {
  var status: AudioDeviceStatus = .unavailable
  var id: UInt32?
  var name: String?
}

enum AudioDeviceKind: String, Codable, CaseIterable, Sendable {
  case output, input

  var label: String { self == .input ? "Input" : "Output" }
}

enum AudioDeviceStatus: String, Codable, CaseIterable, Sendable {
  case available, disconnected, unavailable

  func defaultSymbol(for device: AudioDeviceKind) -> ItemSymbol {
    switch self {
    case .available: device == .input ? "mic.fill" : "speaker.wave.2.fill"
    case .disconnected: device == .input ? "mic.slash" : "speaker.slash"
    case .unavailable: "exclamationmark.triangle"
    }
  }
}
