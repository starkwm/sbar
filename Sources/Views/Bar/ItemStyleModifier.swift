import SwiftUI

struct ItemStyleModifier: ViewModifier {
    let style: ItemStyle

    func body(content: Content) -> some View {
        content
            .font(.system(size: style.fontSize ?? 13, weight: fontWeight))
            .foregroundStyle(Color(hex: style.tint) ?? .primary)
            .padding(.horizontal, style.horizontalPadding ?? 0)
            .padding(.vertical, style.verticalPadding ?? 0)
            .background(
                Color(hex: style.background) ?? .clear,
                in: RoundedRectangle(cornerRadius: style.cornerRadius ?? 0)
            )
    }

    private var fontWeight: Font.Weight {
        switch style.fontWeight ?? .regular {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

extension Color {
    init?(hex: String?) {
        guard let hex, let rgba = RGBA(hex: hex) else { return nil }
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
