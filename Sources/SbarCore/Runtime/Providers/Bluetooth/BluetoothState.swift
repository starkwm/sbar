import Foundation

struct BluetoothState: Equatable, Sendable {
  var status: BluetoothStatus = .unavailable
  var devices: [BluetoothDeviceState] = []

  var text: String { presentation(for: Item(id: "bluetooth", type: .bluetooth)).text }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.bluetooth ?? BluetoothConfiguration()
    let label = settings.labels?[status.rawValue] ?? status.label
    let summary = "Bluetooth \(label)"
    let details =
      status == .connected && !devices.isEmpty
      ? devices.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }.map { device in
        let name = device.name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return "\(name.isEmpty ? "Unnamed device" : name) \(label)"
      }.joined(separator: ", ")
      : summary
    return WidgetPresentation(
      text: settings.showLabel == false ? "" : settings.showName == false ? summary : details,
      symbol: settings.showSymbol == false
        ? nil : item.symbol ?? settings.symbols?.resolve(status) ?? status.defaultSymbol,
      tint: settings.tints?[status.rawValue],
      hidden: (status == .off || status == .on) && settings.hideWhenDisconnected == true,
      accessibilityLabel: details
    )
  }
}

struct BluetoothDeviceState: Equatable, Sendable {
  var id: String
  var name: String
}

enum BluetoothStatus: String, Codable, CaseIterable, Sendable {
  case on, off, connected, unauthorized, unavailable

  var label: String {
    switch self {
    case .unauthorized: "access denied"
    case .on, .off, .connected, .unavailable: rawValue
    }
  }

  var defaultSymbol: ItemSymbol {
    switch self {
    case .on, .connected: "antenna.radiowaves.left.and.right"
    case .off: "antenna.radiowaves.left.and.right.slash"
    case .unauthorized, .unavailable: "exclamationmark.triangle"
    }
  }
}
