import Foundation

extension WidgetState {
  func textValues(for item: Item) -> [String: String] {
    switch self {
    case .cpu(let state):
      let percentage = state.percentage(smoothingSamples: item.cpu?.smoothingSamples ?? 1)
      return [
        "percentage": percentage.map(String.init) ?? "", "available": String(percentage != nil),
      ]
    case .battery(let percentage, let charging, let pluggedIn):
      return [
        "percentage": percentage.map(String.init) ?? "", "charging": String(charging),
        "pluggedIn": String(pluggedIn), "available": String(percentage != nil),
      ]
    case .volume(let percentage, let muted, let available):
      return [
        "percentage": percentage.map(String.init) ?? "", "muted": String(muted),
        "available": String(available),
      ]
    case .memory(let state):
      guard state.available, let used = state.usedBytes, let total = state.totalBytes else {
        return ["available": "false"]
      }
      return [
        "available": "true", "used": state.value(format: .used),
        "total": ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory),
        "percentage": String(Int((Double(used) / Double(total) * 100).rounded())),
        "usedBytes": String(used), "totalBytes": String(total),
      ]
    case .disk(let state):
      guard state.available, let free = state.freeBytes, let total = state.totalBytes else {
        return ["available": "false"]
      }
      return [
        "available": "true", "used": state.value(format: .used), "free": state.value(format: .free),
        "total": state.value(format: .total), "freeBytes": String(free),
        "totalBytes": String(total),
        "percentage": String(Int((Double(total - free) / Double(total) * 100).rounded())),
      ]
    case .media(let state):
      let player = state.selected(source: item.media?.source)
      return [
        "available": String(player != nil && player?.status != .unknown),
        "title": player?.title ?? "", "artist": player?.artist ?? "",
        "source": player?.source.name ?? "",
        "status": player?.status.rawValue ?? "unknown",
        "playing": String(player?.status == .playing),
      ]
    case .mail(let state):
      return [
        "unreadCount": state.status == .available ? state.unreadCount.map(String.init) ?? "" : "",
        "status": state.status.rawValue, "available": String(state.status == .available),
      ]
    case .throughput(let state):
      guard
        let rate = state.rate(
          interfaces: item.throughput?.interfaces,
          smoothingSamples: item.throughput?.smoothingSamples ?? 1
        )
      else {
        return ["available": "false"]
      }
      return [
        "available": "true",
        "download": ThroughputState.format(rate.download, unit: item.throughput?.unit ?? .bytes),
        "upload": ThroughputState.format(rate.upload, unit: item.throughput?.unit ?? .bytes),
      ]
    case .network(let connection):
      let selected =
        item.network?.interface.map { $0 == connection ? connection : .offline } ?? connection
      return ["status": selected.rawValue, "connected": String(selected != .offline)]
    case .vpn(let state):
      let names = state.services.filter { $0.status != .disconnected }.map(\.name).sorted()
      return [
        "status": state.status.rawValue, "names": names.joined(separator: ", "),
        "connected": String(state.status == .connected), "available": String(state.available),
      ]
    case .bluetooth(let state):
      return [
        "status": state.status.rawValue,
        "names": state.devices.map(\.name).sorted().joined(separator: ", "),
        "count": String(state.devices.count), "connected": String(state.status == .connected),
      ]
    case .audioDevice(let state):
      let endpoint = item.audioDevice?.device == .input ? state.input : state.output
      return [
        "name": endpoint.name ?? "", "status": endpoint.status.rawValue,
        "available": String(endpoint.status == .available),
      ]
    case .spaces, .aerospace, .yabai:
      return [:]
    }
  }
}
