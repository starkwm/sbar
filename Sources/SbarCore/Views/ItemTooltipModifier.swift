import SwiftUI

struct ItemTooltipModifier: ViewModifier {
  let text: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let text {
      content.help(text)
    } else {
      content
    }
  }
}
