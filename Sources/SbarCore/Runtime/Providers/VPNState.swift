import Foundation

struct VPNState: Equatable, Sendable {
  var services: [VPNServiceState] = []
  var available = false

  var status: VPNStatus {
    guard available else { return .unavailable }
    return [.unavailable, .connected, .connecting, .disconnecting].first { status in
      services.contains { $0.status == status }
    } ?? .disconnected
  }

  var text: String { presentation(for: Item(id: "vpn", type: .vpn)).text }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.vpn ?? VPNConfiguration()
    let active = services.filter { $0.status != .disconnected }.sorted {
      $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name
    }
    let label = settings.labels?[status.rawValue] ?? status.label
    let summary = "VPN \(label)"
    let details =
      available && !active.isEmpty
      ? active.map { service in
        let name = service.name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let label = settings.labels?[service.status.rawValue] ?? service.status.label
        return "\(name.isEmpty ? "VPN" : name) \(label)"
      }.joined(separator: ", ")
      : summary
    return WidgetPresentation(
      text: settings.showLabel == false ? "" : settings.showName == false ? summary : details,
      symbol: settings.showSymbol == false
        ? nil : item.symbol ?? settings.symbols?.resolve(status) ?? status.defaultSymbol,
      tint: settings.tints?[status.rawValue],
      hidden: status == .disconnected && settings.hideWhenDisconnected == true,
      accessibilityLabel: details
    )
  }
}

struct VPNServiceState: Equatable, Sendable {
  var id: String
  var name: String
  var status: VPNStatus
}

enum VPNStatus: String, Codable, CaseIterable, Sendable {
  case connecting, connected, disconnecting, disconnected, unavailable

  var label: String { rawValue }

  var defaultSymbol: ItemSymbol {
    switch self {
    case .connected: "lock.shield.fill"
    case .connecting, .disconnecting: "arrow.triangle.2.circlepath"
    case .disconnected: "lock.shield"
    case .unavailable: "exclamationmark.shield"
    }
  }
}
