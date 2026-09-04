import AppKit
import SwiftUI

struct BarItemView: View {
    let configuration: ItemConfiguration

    var body: some View {
        if let symbol = configuration.symbol, configuration.type != .divider, configuration.type != .spacer {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch configuration.type {
        case .clock:
            Text(providers.date, format: clockFormat).monospacedDigit()
        case .date:
            Text(providers.date, format: .dateTime.weekday().month().day())
        case .divider:
            Rectangle().frame(width: 1, height: 16).opacity(0.3)
        case .frontApplication:
            Text(configuration.label ?? providers.values[.frontApplication] ?? "").lineLimit(1)
        case .spacer:
            Spacer(minLength: 8)
        case .text:
            Text(configuration.label ?? "")
        default:
            Text(providers.values[configuration.type] ?? "—")
        }
    }

    @Environment(ProviderRegistry.self) private var providers

    private var clockFormat: Date.FormatStyle {
        switch configuration.format {
        case "HH:mm:ss": .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()
        case "HH:mm": .dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        default: .dateTime.hour().minute()
        }
    }
}
