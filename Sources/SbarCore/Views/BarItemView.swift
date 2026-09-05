import AppKit
import SwiftUI

struct BarItemView: View {
  let configuration: Item

  var body: some View {
    if let symbol = configuration.symbol, configuration.type != .divider,
      configuration.type != .spacer
    {
      HStack(spacing: 4) {
        Image(systemName: symbol).accessibilityHidden(true)
        content
      }
    } else {
      content
    }
  }

  @ViewBuilder private var content: some View {
    switch configuration.type {
    case .clock:
      Text(
        ClockFormatter.string(
          providers.itemDates[configuration.id] ?? providers.currentDate,
          format: configuration.format
        )
      ).monospacedDigit()
    case .date:
      Text(
        providers.itemDates[configuration.id] ?? providers.currentDate,
        format: .dateTime.weekday().month().day()
      )
    case .divider:
      Rectangle().frame(width: 1, height: 16).opacity(0.3).accessibilityHidden(true)
    case .frontApplication:
      Text(
        configuration.label ?? providers.itemSnapshots[configuration.id] ?? providers.sharedValues[
          .frontApplication
        ] ?? ""
      ).lineLimit(1)
    case .spacer:
      Spacer(minLength: 8).accessibilityHidden(true)
    case .text:
      Text(configuration.label ?? "")
    case .command, .plugin:
      Text(providers.itemValues[configuration.id] ?? "…")
    case .group, .popup:
      Text(configuration.label ?? configuration.id)
    default:
      Text(
        providers.itemSnapshots[configuration.id] ?? providers.sharedValues[configuration.type]
          ?? "—"
      )
    }
  }

  @Environment(ProviderRuntime.self) private var providers
}
