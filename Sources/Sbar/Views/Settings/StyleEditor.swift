import SwiftUI

struct StyleEditor: View {
  @Binding var style: ItemStyle

  var body: some View {
    TextField("Tint (#RRGGBB)", text: string(\.tint))
    TextField("Background (#RRGGBBAA)", text: string(\.background))
    TextField("Font size", value: $style.fontSize, format: .number)
    Picker("Weight", selection: $style.fontWeight) {
      Text("Inherit").tag(nil as ItemFontWeight?)
      ForEach(ItemFontWeight.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
    }
    TextField("Horizontal padding", value: $style.horizontalPadding, format: .number)
    TextField("Vertical padding", value: $style.verticalPadding, format: .number)
    TextField("Corner radius", value: $style.cornerRadius, format: .number)
  }

  private func string(_ key: WritableKeyPath<ItemStyle, String?>) -> Binding<String> {
    Binding(
      get: { style[keyPath: key] ?? "" },
      set: { style[keyPath: key] = $0.isEmpty ? nil : $0 }
    )
  }
}
