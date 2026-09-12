import Foundation

struct PluginState: Equatable, Sendable {
  static func restartDelay(_ delay: Double, uptime: Duration, receivedOutput: Bool) -> Double {
    receivedOutput && uptime >= .seconds(30) ? 1 : delay
  }

  var status: CommandState.Status = .running
  var lastSuccess: PluginOutput?
  var error: String?

  func presentation(for item: Item) -> WidgetPresentation {
    var adapted = item
    let settings = item.plugin
    adapted.command = ShellCommand(
      script: "plugin",
      maxLength: settings?.maxLength ?? 4096,
      onError: settings?.onError,
      symbols: settings?.symbols,
      tints: settings?.tints,
      showSymbol: settings?.showSymbol
    )
    return CommandState(status: status, lastSuccess: lastSuccess, error: error).presentation(
      for: adapted
    )
  }
}
