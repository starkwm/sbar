import AppKit
import SwiftUI

struct BarItemView: View {
    let configuration: ItemConfiguration

    var body: some View {
        switch configuration.type {
        case .clock:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: clockFormat).monospacedDigit()
            }
        case .divider:
            Divider().frame(height: 16)
        case .frontApplication:
            Text(configuration.label ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "").lineLimit(1)
        case .spacer:
            Spacer(minLength: 8)
        case .text:
            if let symbol = configuration.symbol {
                Label(configuration.label ?? "", systemImage: symbol)
            } else {
                Text(configuration.label ?? "")
            }
        }
    }

    private var clockFormat: Date.FormatStyle {
        switch configuration.format {
        case "HH:mm:ss": .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()
        case "HH:mm": .dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        default: .dateTime.hour().minute()
        }
    }
}
