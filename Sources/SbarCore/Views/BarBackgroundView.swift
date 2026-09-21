import AppKit
import SwiftUI

struct BarBackgroundView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    // The bar never becomes key, including after a Space transition.
    view.state = .active

    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
