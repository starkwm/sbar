import SwiftUI

struct ItemStyleModifier: ViewModifier {
  let style: ItemStyle
  var hovering = false

  private var font: Font {
    let size = style.fontSize ?? 13
    let weight = (style.fontWeight ?? .regular).swiftUIWeight

    if let family = style.fontFamily {
      return .custom(family, size: size).weight(weight)
    }

    return .system(size: size, weight: weight)
  }

  func body(content: Content) -> some View {
    sizedContent(
      content
        .font(font)
        .foregroundStyle(
          Color(hex: hovering ? style.hoverTint ?? style.tint : style.tint) ?? .primary
        )
        .padding(.horizontal, style.horizontalPadding ?? 0)
        .padding(.vertical, style.verticalPadding ?? 0)
    )
    .background {
      let shape = RoundedRectangle(cornerRadius: style.cornerRadius ?? 0)
      ZStack {
        shape.fill(
          Color(hex: hovering ? style.hoverBackground ?? style.background : style.background)
            ?? .clear
        )

        if hovering && style.hoverBackground == nil {
          shape.fill(Color.primary.opacity(0.08))
        }
      }
    }
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
