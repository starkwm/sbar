import Foundation

@MainActor
final class EventBus {
  private(set) var recent: [RuntimeEvent] = []

  var onEvent: ((RuntimeEvent) -> Void)?

  func emit(_ event: RuntimeEvent) {
    recent.append(event)

    if recent.count > 100 { recent.removeFirst(recent.count - 100) }

    onEvent?(event)
  }
}

struct RuntimeEvent: Codable, Sendable {
  enum Kind: String, Codable, Sendable { case configuration, trigger, provider }

  let kind: Kind
  let name: String
  let value: JSONValue?
}
