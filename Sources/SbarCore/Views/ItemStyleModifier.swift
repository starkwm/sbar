import SwiftUI

struct ItemStyleModifier: ViewModifier {
  let style: ItemStyle

  func body(content: Content) -> some View {
    sizedContent(
      content
        .font(
          .system(size: style.fontSize ?? 13, weight: (style.fontWeight ?? .regular).swiftUIWeight)
        )
        .foregroundStyle(Color(hex: style.tint) ?? .primary)
        .padding(.horizontal, style.horizontalPadding ?? 0)
        .padding(.vertical, style.verticalPadding ?? 0)
    )
    .background(
      Color(hex: style.background) ?? .clear,
      in: RoundedRectangle(cornerRadius: style.cornerRadius ?? 0)
    )
  }

  @ViewBuilder
  private func sizedContent<StyledContent: View>(_ content: StyledContent) -> some View {
    let alignment = (style.alignment ?? .center).swiftUIAlignment
    if let width = style.width {
      content
        .lineLimit(1)
        .truncationMode(.tail)
        .minimumScaleFactor(1)
        .frame(width: width, alignment: alignment)
        .clipped()
    } else {
      content.frame(minWidth: style.minWidth.map { CGFloat($0) }, alignment: alignment)
    }
  }
}

extension ItemAlignment {
  var swiftUIAlignment: Alignment {
    switch self {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }
}

extension ItemFontWeight {
  var swiftUIWeight: Font.Weight {
    switch self {
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
