import AppKit
import SwiftUI

struct BarItemView: View {
  let configuration: Item
  var symbolFontSize: Double = 13
  var symbolFontWeight: ItemFontWeight?

  var body: some View {
    if let presentation = providers.presentation(for: configuration) {
      HStack(spacing: 4) {
        if let symbol = presentation.symbol {
          ItemSymbolView(symbol: symbol, fontSize: symbolFontSize, fontWeight: symbolFontWeight)
        }
        if !presentation.segments.isEmpty {
          ForEach(presentation.segments.indices, id: \.self) { index in
            let segment = presentation.segments[index]
            HStack(spacing: 4) {
              if let symbol = segment.symbol {
                ItemSymbolView(
                  symbol: symbol,
                  fontSize: symbolFontSize,
                  fontWeight: symbolFontWeight
                )
              }
              if !segment.text.isEmpty { Text(segment.text).monospacedDigit() }
            }
          }
        } else if !presentation.text.isEmpty {
          Text(presentation.text).monospacedDigit()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(presentation.accessibilityLabel)
    } else if let icon = providers.applicationIcon(for: configuration) {
      HStack(spacing: 4) {
        Image(nsImage: icon)
          .renderingMode(.original)
          .resizable()
          .scaledToFit()
          .frame(width: symbolFontSize, height: symbolFontSize)
          .accessibilityHidden(true)
        content
      }
    } else if let symbol = configuration.symbol, configuration.type != .divider,
      configuration.type != .spacer
    {
      HStack(spacing: 4) {
        ItemSymbolView(symbol: symbol, fontSize: symbolFontSize, fontWeight: symbolFontWeight)
          .accessibilityHidden(true)
        content
      }
    } else {
      content
    }
  }

  @ViewBuilder private var content: some View {
    switch configuration.type {
    case .datetime:
      Text(
        DateTimeFormatter.string(
          providers.itemDates[configuration.id] ?? providers.currentDate,
          format: configuration.format,
          dateStyle: configuration.dateStyle,
          timeStyle: configuration.timeStyle
        )
      ).monospacedDigit()
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
    case .network where configuration.network?.showLabel == false:
      EmptyView()
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
