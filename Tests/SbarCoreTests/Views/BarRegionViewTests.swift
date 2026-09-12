import AppKit
import SwiftUI
import Testing

@testable import SbarCore

@Suite("BarRegionView")
@MainActor
struct BarRegionViewTests {
  @Test("a hidden media item renders like an absent item in a narrow region")
  func hiddenMedia() throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(.media(MediaState()), for: .media)
    let text = Item(id: "text", type: .text, text: "Hi")
    let media = Item(
      id: "media",
      type: .media,
      priority: 10,
      media: MediaConfiguration(hideWhenNotPlaying: true)
    )
    #expect(try render([text, media], runtime: runtime) == render([text], runtime: runtime))
  }

  private func render(_ items: [Item], runtime: ProviderRuntime) throws -> Data {
    let renderer = ImageRenderer(
      content: BarRegionView(items: items, theme: nil, alignment: .leading)
        .frame(width: 40, height: 32)
        .environment(runtime)
        .environment(ActionRunner())
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, .leftToRight)
        .foregroundStyle(.black)
        .background(.white)
    )
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    )
  }
}
