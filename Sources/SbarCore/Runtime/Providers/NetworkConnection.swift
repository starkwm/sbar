enum NetworkConnection: String, CaseIterable, Sendable {
  case wifi, ethernet, cellular, other, offline

  static func classify(
    connected: Bool,
    wifi: Bool,
    ethernet: Bool,
    cellular: Bool
  ) -> Self {
    guard connected else { return .offline }
    if wifi { return .wifi }
    if ethernet { return .ethernet }
    if cellular { return .cellular }
    return .other
  }

  var text: String {
    switch self {
    case .wifi: "Wi-Fi"
    case .offline: "Offline"
    case .ethernet, .cellular, .other: "Connected"
    }
  }

  var defaultSymbol: ItemSymbol {
    switch self {
    case .wifi: "wifi"
    case .ethernet: "cable.connector"
    case .cellular: "antenna.radiowaves.left.and.right"
    case .other: "network"
    case .offline: "network.slash"
    }
  }
}
