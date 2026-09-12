import AppKit
import SwiftUI

struct BarItemView: View {
  let configuration: Item
  var symbolFontSize: Double = 13
  var symbolFontWeight: ItemFontWeight?
  var tintOverride: String?

  var body: some View {
    if let presentation = providers.presentation(for: configuration, displayUUID: barDisplayUUID) {
      SymbolContentView(position: configuration.symbolPosition) {
        if let icon = providers.applicationIcon(for: configuration) {
          Image(nsImage: icon)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: symbolFontSize, height: symbolFontSize)
            .accessibilityHidden(true)
        } else if let symbol = presentation.symbol {
          ItemSymbolView(symbol: symbol, fontSize: symbolFontSize, fontWeight: symbolFontWeight)
        }
      } content: {
        if !presentation.segments.isEmpty {
          ForEach(presentation.segments.indices, id: \.self) { index in
            let segment = presentation.segments[index]
            SymbolContentView(position: configuration.symbolPosition) {
              if let symbol = segment.symbol {
                ItemSymbolView(
                  symbol: symbol,
                  fontSize: symbolFontSize,
                  fontWeight: symbolFontWeight
                )
              }
            } content: {
              if !segment.text.isEmpty { Text(segment.text).monospacedDigit() }
            }
            .foregroundColor(Color(hex: tintOverride ?? segment.tint))
            .fontWeight(segment.emphasized ? .bold : nil)
          }
        } else if !presentation.text.isEmpty {
          Text(presentation.text).monospacedDigit()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(presentation.accessibilityLabel)
    } else if let icon = providers.applicationIcon(for: configuration) {
      SymbolContentView(position: configuration.symbolPosition) {
        Image(nsImage: icon)
          .renderingMode(.original)
          .resizable()
          .scaledToFit()
          .frame(width: symbolFontSize, height: symbolFontSize)
          .accessibilityHidden(true)
      } content: {
        content
      }
    } else if let symbol = configuration.symbol, configuration.type != .divider,
      configuration.type != .spacer
    {
      SymbolContentView(position: configuration.symbolPosition) {
        ItemSymbolView(symbol: symbol, fontSize: symbolFontSize, fontWeight: symbolFontWeight)
          .accessibilityHidden(true)
      } content: {
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
        providers.itemSnapshots[configuration.id] ?? providers.sharedValues[
          .frontApplication
        ] ?? ""
      ).lineLimit(1)
    case .spacer:
      Spacer(minLength: 8).accessibilityHidden(true)
    case .text:
      Text("")
    case .command, .plugin:
      Text(providers.itemValues[configuration.id] ?? "…")
    case .group, .popup:
      Text(configuration.id)
    default:
      Text(
        providers.itemSnapshots[configuration.id] ?? providers.sharedValues[configuration.type]
          ?? "—"
      )
    }
  }

  @Environment(\.barDisplayUUID) private var barDisplayUUID

  @Environment(ProviderRuntime.self) private var providers
}

private struct SymbolContentView<Symbol: View, Content: View>: View {
  var position: ItemSymbolPosition
  @ViewBuilder var symbol: Symbol
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 4) {
      if position == .left { symbol }
      content
      if position == .right { symbol }
    }
  }
}
