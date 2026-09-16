import AppKit
import SwiftUI
import Testing

@testable import SbarCore

@Suite("VerticalBarView")
@MainActor
struct VerticalBarViewTests {
  @Test(
    "nested groups stack upright children and preserve spacing on both edges",
    arguments: [BarPosition.left, .right]
  )
  func groups(position: BarPosition) throws {
    let runtime = ProviderRuntime()
    let children = [
      Item(id: "a", type: .text, text: "One"), Item(id: "b", type: .text, text: "Two"),
    ]
    let group = Item(id: "group", type: .group, children: children, itemSpacing: 9)
    let nested = Item(id: "nested", type: .group, children: [group])
    let actual = try render(
      InteractiveItemView(item: nested, defaultStyle: nil)
        .environment(\.barPosition, position),
      runtime: runtime
    )
    let expected = try render(
      VStack(spacing: 9) {
        ForEach(children) { child in InteractiveItemView(item: child, defaultStyle: nil) }
      },
      runtime: runtime
    )
    #expect(actual == expected)
    let horizontal = try render(
      InteractiveItemView(item: nested, defaultStyle: nil),
      runtime: runtime
    )
    #expect(actual != horizontal)
  }

  @Test(
    "side dividers run horizontally and icon-label rows stay upright",
    arguments: [BarPosition.left, .right]
  )
  func itemOrientation(position: BarPosition) throws {
    let runtime = ProviderRuntime()
    let divider = Item(id: "divider", type: .divider)
    let vertical = try render(
      BarItemView(configuration: divider)
        .environment(\.barPosition, position),
      runtime: runtime
    )
    let expected = try render(
      Rectangle().frame(width: 16, height: 1).opacity(0.3),
      runtime: runtime
    )
    #expect(vertical == expected)
    let text = Item(id: "text", type: .text, text: "Hello", symbol: .system("star"))
    #expect(
      try render(
        BarItemView(configuration: text).environment(\.barPosition, position),
        runtime: runtime
      )
        == render(BarItemView(configuration: text), runtime: runtime)
    )
  }

  @Test("segmented Spaces stack vertically with upright labels")
  func segmentedProvider() throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(
      .spaces(
        SpacesState(
          displays: [
            SpaceDisplay(
              identifier: "main",
              spaces: [SpaceEntry(id: 1), SpaceEntry(id: 2)],
              activeID: 1
            )
          ],
          focusedID: 1
        )
      ),
      for: .spaces
    )
    let item = Item(
      id: "spaces",
      type: .spaces,
      text: "{{#workspaces}}{{name}}{{^last}} {{/last}}{{/workspaces}}",
      spaces: SpacesConfiguration(showSymbol: false)
    )
    let horizontal = try #require(
      NSBitmapImageRep(data: render(BarItemView(configuration: item), runtime: runtime))
    )
    let vertical = try #require(
      NSBitmapImageRep(
        data: render(
          BarItemView(configuration: item)
            .environment(\.barPosition, .left),
          runtime: runtime
        )
      )
    )
    #expect(vertical.pixelsHigh > horizontal.pixelsHigh)
    #expect(vertical.pixelsWide < horizontal.pixelsWide)
  }

  private func render<V: View>(_ content: V, runtime: ProviderRuntime) throws -> Data {
    let renderer = ImageRenderer(
      content:
        content
        .environment(runtime).environment(ActionRunner())
        .environment(\.colorScheme, .light).environment(\.layoutDirection, .leftToRight)
        .foregroundStyle(.black).fixedSize().background(.white)
    )
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image)
        .representation(using: .png, properties: [:])
    )
  }
}
