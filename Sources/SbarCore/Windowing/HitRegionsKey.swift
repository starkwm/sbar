import SwiftUI

struct HitRegionsKey: PreferenceKey {
  static let defaultValue: [CGRect] = []

  static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
    value.append(contentsOf: nextValue())
  }
}

struct HitRegionModifier: ViewModifier {
  var enabled = true

  func body(content: Content) -> some View {
    content.background(
      GeometryReader { geometry in
        Color.clear.preference(
          key: HitRegionsKey.self,
          value: enabled ? [geometry.frame(in: .named("bar"))] : []
        )
      }
    )
  }
}
