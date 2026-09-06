import SwiftUI

struct ItemSymbolView: View {
  let symbol: ItemSymbol
  var fontSize: Double = 13
  var fontWeight: ItemFontWeight?

  var body: some View {
    Group {
      switch symbol {
      case .system(let name):
        Image(systemName: name).fontWeight(fontWeight?.swiftUIWeight)
      case .glyph(let glyph, let font, let size):
        Text(glyph).font(.custom(font, size: size ?? fontSize))
      }
    }
    .accessibilityHidden(true)
  }
}
