import AppKit
import Foundation

@MainActor
final class ControlRouter {
  private let store: ConfigurationStore
  private let providers: ProviderRuntime
  private let events: EventBus
  private let actions: ActionRunner

  init(
    store: ConfigurationStore,
    providers: ProviderRuntime,
    events: EventBus,
    actions: ActionRunner
  ) {
    self.store = store
    self.providers = providers
    self.events = events
    self.actions = actions
  }

  func handle(_ request: ControlRequest) -> ControlResponse {
    do {
      switch request.command {
      case "stop":
        return ControlResponse()

      case "query":
        if request.arguments == ["diagnostics"] {
          return ControlResponse(
            value: .object([
              "configurationPath": .string(store.configurationURL.path),
              "configurationError": store.errorMessage.map(JSONValue.string) ?? .null,
              "actionError": actions.errorMessage.map(JSONValue.string) ?? .null,
              "events": try JSONDecoder().decode(
                JSONValue.self,
                from: JSONEncoder().encode(events.recent)
              ),
            ])
          )
        }

        if request.arguments == ["displays"] {
          return ControlResponse(
            value: .array(
              NSScreen.screens.enumerated().compactMap { index, screen in
                guard
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? NSNumber
                else { return nil }

                return .object([
                  "id": .number(number.doubleValue),
                  "name": .string(screen.localizedName),
                  "primary": .bool(index == 0),
                ])
              }
            )
          )
        }

        guard request.arguments.isEmpty else {
          throw MessageError.message("Unknown query selector.")
        }

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
          throw MessageError.message("Expected event name.")
        }

        providers.trigger(request.arguments[0], value: request.value)
        events.emit(RuntimeEvent(kind: .trigger, name: request.arguments[0], value: request.value))

        return ControlResponse()

      case "set":
        guard request.arguments.count == 2, let value = request.value else {
          throw MessageError.message("Expected item ID, property and value.")
        }

        let id = request.arguments[0]
        let property = request.arguments[1]
        guard
          [
            "label", "symbol", "enabled", "priority", "format", "dateStyle", "timeStyle", "style",
            "popup",
          ].contains(property)
        else { throw MessageError.message("Property cannot be changed at runtime.") }

        var candidate = store.configuration

        func update(_ items: inout [Item]) throws -> Bool {
          for index in items.indices {
            if items[index].id == id {
              let encoded = try JSONEncoder().encode(items[index])
              guard
                case .object(var object) = try JSONDecoder().decode(JSONValue.self, from: encoded)
              else { return false }

              object[property] = value
              items[index] = try JSONDecoder().decode(
                Item.self,
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
        guard found else { throw MessageError.message("Unknown item ID: \(id)") }

        try store.apply(candidate)

        return ControlResponse()

      default: throw MessageError.message("Unknown command.")
      }
    } catch { return ControlResponse(ok: false, error: error.localizedDescription) }
  }
}
