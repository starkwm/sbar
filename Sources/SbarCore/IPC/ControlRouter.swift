import Foundation

@MainActor
final class ControlRouter {
  private let store: ConfigurationStore
  private let providers: ProviderRegistry
  private let events: EventBus

  init(store: ConfigurationStore, providers: ProviderRegistry, events: EventBus) {
    self.store = store
    self.providers = providers
    self.events = events
  }

  func handle(_ request: ControlRequest) -> ControlResponse {
    do {
      switch request.command {
      case "query":
        return ControlResponse(
          value: try JSONDecoder().decode(
            JSONValue.self,
            from: JSONEncoder().encode(store.configuration)
          )
        )
      case "reload":
        store.load()
        if let error = store.errorMessage { return ControlResponse(ok: false, error: error) }
        return ControlResponse()
      case "subscribe": return ControlResponse(value: .string("subscribed"))
      case "trigger":
        guard request.arguments.count == 1 else {
          throw SocketFailure.message("Expected event name.")
        }
        providers.trigger(request.arguments[0], value: request.value)
        events.emit(RuntimeEvent(kind: .trigger, name: request.arguments[0], value: request.value))
        return ControlResponse()
      case "set":
        guard request.arguments.count == 2, let value = request.value else {
          throw SocketFailure.message("Expected item ID, property and value.")
        }
        let id = request.arguments[0]
        let property = request.arguments[1]
        guard
          ["label", "symbol", "enabled", "priority", "format", "style", "popup"].contains(property)
        else { throw SocketFailure.message("Property cannot be changed at runtime.") }
        var candidate = store.configuration
        func update(_ items: inout [ItemConfiguration]) throws -> Bool {
          for index in items.indices {
            if items[index].id == id {
              let encoded = try JSONEncoder().encode(items[index])
              guard
                case .object(var object) = try JSONDecoder().decode(JSONValue.self, from: encoded)
              else { return false }
              object[property] = value
              items[index] = try JSONDecoder().decode(
                ItemConfiguration.self,
                from: JSONEncoder().encode(JSONValue.object(object))
              )
              return true
            }
            if var children = items[index].children, try update(&children) {
              items[index].children = children
              return true
            }
          }
          return false
        }
        let found =
          try update(&candidate.items.left) || update(&candidate.items.center)
          || update(&candidate.items.right)
        guard found else { throw SocketFailure.message("Unknown item ID: \(id)") }
        try store.apply(candidate)
        return ControlResponse()
      default: throw SocketFailure.message("Unknown command.")
      }
    } catch { return ControlResponse(ok: false, error: error.localizedDescription) }
  }
}
