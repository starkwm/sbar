import Foundation
import Observation

struct RuntimeEvent: Codable, Sendable {
  enum Kind: String, Codable, Sendable { case configuration, trigger, provider }

  let kind: Kind
  let name: String
  let value: JSONValue?
}

@MainActor @Observable
final class EventBus {
  private(set) var recent: [RuntimeEvent] = []

  @ObservationIgnored var onEvent: ((RuntimeEvent) -> Void)?

  func emit(_ event: RuntimeEvent) {
    recent.append(event)
    if recent.count > 100 { recent.removeFirst(recent.count - 100) }

    onEvent?(event)
  }
}
