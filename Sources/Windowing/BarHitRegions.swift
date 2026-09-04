import SwiftUI

struct BarHitRegions: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value.append(contentsOf: nextValue()) }
}

struct BarHitRegion: ViewModifier {
    var enabled = true

    func body(content: Content) -> some View {
        content.background(GeometryReader { geometry in
            Color.clear.preference(key: BarHitRegions.self, value: enabled ? [geometry.frame(in: .named("bar"))] : [])
        })
    }
}
