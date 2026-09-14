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

  @Test("empty styled sections draw nothing, including hidden media")
  func emptyStyle() throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(.media(MediaState()), for: .media)
    let media = Item(id: "media", type: .media, media: MediaConfiguration(hideWhenNotPlaying: true))
    let theme = Theme(
      regionStyle: RegionStyle(
        background: "#FF0000",
        cornerRadius: 8,
        horizontalPadding: 10,
        borderColor: "#00FF00",
        borderWidth: 2
      )
    )
    #expect(try render([], runtime: runtime, theme: theme) == render([], runtime: runtime))
    #expect(try render([media], runtime: runtime, theme: theme) == render([], runtime: runtime))
  }

  @Test("section overrides render like equivalent shared defaults")
  func overrides() throws {
    let runtime = ProviderRuntime()
    let item = Item(id: "text", type: .text, text: "Hi")
    let base = RegionStyle(background: "#FF0000", cornerRadius: 8, horizontalPadding: 4)
    let override = RegionStyle(background: "#00FF00", cornerRadius: 0)
    #expect(
      try render([item], runtime: runtime, theme: Theme(regionStyle: base), style: override)
        == render(
          [item],
          runtime: runtime,
          theme: Theme(regionStyle: override.resolved(over: base))
        )
    )
  }

  @Test("background hugs fixed items and follows section alignment")
  func backgroundBounds() throws {
    let runtime = ProviderRuntime()
    let item = Item(id: "spacer", type: .spacer, style: ItemStyle(width: 10))
    let theme = Theme(regionStyle: RegionStyle(background: "#FF0000", horizontalPadding: 2))
    for alignment in [Alignment.leading, .center, .trailing] {
      let data = try render([item], runtime: runtime, theme: theme, alignment: alignment)
      let bitmap = try #require(NSBitmapImageRep(data: data))
      var redColumns: [Int] = []
      for x in 0..<bitmap.pixelsWide {
        let color = try #require(
          bitmap.colorAt(x: x, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB)
        )
        if color.redComponent > 0.9 && color.greenComponent < 0.3 { redColumns.append(x) }
      }
      #expect(redColumns.count == 28)
      #expect(redColumns.first == (alignment == .leading ? 0 : alignment == .center ? 26 : 52))
    }
  }

  @Test("padding reserves space for the overflow button")
  func paddedOverflow() throws {
    let runtime = ProviderRuntime()
    let item = Item(id: "wide", type: .spacer, style: ItemStyle(width: 35))
    let wider = Item(id: "wider", type: .spacer, style: ItemStyle(width: 100))
    let theme = Theme(regionStyle: RegionStyle(background: "#FF0000", horizontalPadding: 4))
    // Both must overflow: 35 points fits the region, but not its 32-point padded interior.
    #expect(
      try render([item], runtime: runtime, theme: theme)
        == render([wider], runtime: runtime, theme: theme)
    )
    #expect(
      try render([item], runtime: runtime, theme: theme)
        != render(
          [item],
          runtime: runtime,
          theme: Theme(regionStyle: RegionStyle(background: "#FF0000"))
        )
    )
  }

  @Test("rounded corners and inset borders decorate the section")
  func borderAndCorners() throws {
    let runtime = ProviderRuntime()
    let item = Item(id: "space", type: .spacer, style: ItemStyle(width: 32))
    let square = Theme(regionStyle: RegionStyle(background: "#FF0000"))
    let rounded = Theme(regionStyle: RegionStyle(background: "#FF0000", cornerRadius: 8))
    let bordered = Theme(
      regionStyle: RegionStyle(
        background: "#FF0000",
        cornerRadius: 8,
        borderColor: "#00FF00",
        borderWidth: 2
      )
    )
    let plain = try render([item], runtime: runtime, theme: square)
    let curved = try render([item], runtime: runtime, theme: rounded)
    let outlined = try render([item], runtime: runtime, theme: bordered)
    #expect(plain != curved)
    #expect(curved != outlined)
    let bitmap = try #require(NSBitmapImageRep(data: curved))
    let corner = try #require(bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
    #expect(corner.redComponent > 0.9 && corner.greenComponent > 0.9)
    let borderBitmap = try #require(NSBitmapImageRep(data: outlined))
    let edge = try #require(borderBitmap.colorAt(x: 1, y: 32)?.usingColorSpace(.sRGB))
    #expect(edge.greenComponent > 0.8 && edge.redComponent < 0.3)
  }

  @Test("groups with only hidden children draw no section decoration")
  func hiddenGroups() throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(.media(MediaState()), for: .media)
    let media = Item(id: "media", type: .media, media: MediaConfiguration(hideWhenNotPlaying: true))
    let disabled = Item(id: "disabled", type: .text, enabled: false, text: "Hidden")
    let group = Item(id: "group", type: .group, children: [media, disabled])
    let nested = Item(id: "nested", type: .group, children: [group])
    let empty = Item(id: "empty", type: .group)
    let theme = Theme(regionStyle: RegionStyle(background: "#FF0000", horizontalPadding: 10))
    for item in [group, nested, empty] {
      #expect(!runtime.isVisible(item))
      #expect(
        try render([item], runtime: runtime, theme: theme)
          == render([], runtime: runtime, theme: theme)
      )
    }
  }

  @Test("groups remain visible when a nested child is visible")
  func visibleGroups() throws {
    let runtime = ProviderRuntime()
    let text = Item(id: "text", type: .text, text: "Hi")
    let group = Item(id: "group", type: .group, children: [text])
    let nested = Item(id: "nested", type: .group, children: [group])
    let popup = Item(id: "popup", type: .popup)
    let theme = Theme(regionStyle: RegionStyle(background: "#FF0000", horizontalPadding: 10))
    #expect(runtime.isVisible(nested))
    #expect(runtime.isVisible(popup))
    #expect(
      try render([nested], runtime: runtime, theme: theme)
        != render([], runtime: runtime, theme: theme)
    )
  }

  private func render(
    _ items: [Item],
    runtime: ProviderRuntime,
    theme: Theme? = nil,
    style: RegionStyle? = nil,
    alignment: Alignment = .leading
  ) throws -> Data {
    let renderer = ImageRenderer(
      content: BarRegionView(items: items, theme: theme, alignment: alignment, style: style)
        .frame(width: 40, height: 32)
        .environment(runtime)
        .environment(ActionRunner())
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, .leftToRight)
        .foregroundStyle(.black)
        .background(.white)
    )
    renderer.proposedSize = ProposedViewSize(width: 40, height: 32)
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    )
  }
}
