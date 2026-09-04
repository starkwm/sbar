import AppKit
import SwiftUI

struct BarItemView: View {
  let configuration: ItemConfiguration

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
        ClockText.string(
          providers.dates[configuration.id] ?? providers.date,
          format: configuration.format
        )
      ).monospacedDigit()
    case .date:
      Text(
        providers.dates[configuration.id] ?? providers.date,
        format: .dateTime.weekday().month().day()
      )
    case .divider:
      Rectangle().frame(width: 1, height: 16).opacity(0.3).accessibilityHidden(true)
    case .frontApplication:
      Text(
        configuration.label ?? providers.snapshots[configuration.id] ?? providers.values[
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
      Text(providers.snapshots[configuration.id] ?? providers.values[configuration.type] ?? "—")
    }
  }

  @Environment(ProviderRegistry.self) private var providers

}
