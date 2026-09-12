import AppKit
import SwiftUI
import Testing

@testable import SbarCore

@Suite("ItemStyleModifier")
@MainActor
struct ItemStyleModifierTests {
  @Test("fixed widths include symbols and padding and survive changing labels")
  func fixedWidths() throws {
    let style = ItemStyle(horizontalPadding: 8, minWidth: 200, width: 80)
    for label in ["9%", "100%", "A much longer application name that must truncate"] {
      let item = Item(id: "item", type: .text, label: label, symbol: "star.fill", style: style)
      let image = try render(item)
      #expect(image.pixelsWide == 80)
      #expect(image.pixelsHigh < 32)
    }
  }

  @Test("minimum widths reserve space for short labels and grow for long labels")
  func minimumWidths() throws {
    var item = Item(
      id: "item",
      type: .text,
      label: "9%",
      symbol: "star.fill",
      style: ItemStyle(horizontalPadding: 8, minWidth: 100)
    )
    #expect(try render(item).pixelsWide == 100)
    item.label = "100%"
    #expect(try render(item).pixelsWide == 100)
    item.label = "A much longer application name that needs more space"
    #expect(try render(item).pixelsWide > 100)
    item.style = nil
    let naturalWidth = try render(item).pixelsWide
    item.style = ItemStyle(minWidth: 0)
    #expect(try render(item).pixelsWide == naturalWidth)
  }

  @Test("provider updates preserve inherited widths for interactive items")
  func providerUpdates() throws {
    let runtime = ProviderRuntime()
    let item = Item(id: "battery", type: .battery, popup: "Battery status")
    let style = ItemStyle(horizontalPadding: 8, width: 100, alignment: .trailing)
    for percentage in [9, 100] {
      runtime.updateWidgetState(
        .battery(percentage: percentage, charging: false, pluggedIn: false),
        for: .battery
      )
      #expect(try render(item, runtime: runtime, defaultStyle: style).pixelsWide == 100)
    }
  }

  @Test(
    "content aligns inside the reserved width with padding and a full background",
    arguments: ItemAlignment.allCases,
    [false, true]
  )
  func alignment(alignment: ItemAlignment, fixed: Bool) throws {
    let style = ItemStyle(
      background: "#0000FF",
      horizontalPadding: 6,
      minWidth: fixed ? nil : 80,
      width: fixed ? 80 : nil,
      alignment: alignment
    )
    let image = try render(
      Rectangle().fill(Color(red: 1, green: 0, blue: 0))
        .frame(width: 10, height: 10)
        .modifier(ItemStyleModifier(style: style))
    )
    #expect(image.pixelsWide == 80)
    let redColumns = (0..<image.pixelsWide).filter { x in
      let color = image.colorAt(x: x, y: 5)?.usingColorSpace(.deviceRGB)
      return (color?.redComponent ?? 0) > 0.9
    }
    let start =
      switch alignment {
      case .leading: 6
      case .center: 35
      case .trailing: 64
      }
    #expect(redColumns == Array(start..<(start + 10)))
    #expect(image.colorAt(x: 0, y: 5)?.usingColorSpace(.deviceRGB)?.blueComponent == 1)
    #expect(image.colorAt(x: 79, y: 5)?.usingColorSpace(.deviceRGB)?.blueComponent == 1)
  }

  @Test("fixed widths clip oversized content before it reaches neighbouring items")
  func clipping() throws {
    let image = try render(
      Rectangle().fill(Color(red: 1, green: 0, blue: 0))
        .frame(width: 140, height: 10)
        .modifier(ItemStyleModifier(style: ItemStyle(width: 80)))
        .padding(.horizontal, 20)
        .background(.black)
    )
    #expect(image.pixelsWide == 120)
    let redColumns = (0..<image.pixelsWide).filter { x in
      (image.colorAt(x: x, y: 5)?.usingColorSpace(.deviceRGB)?.redComponent ?? 0) > 0.9
    }
    #expect(redColumns == Array(20..<100))
  }

  private func render(
    _ item: Item,
    runtime: ProviderRuntime = ProviderRuntime(),
    defaultStyle: ItemStyle? = nil
  ) throws -> NSBitmapImageRep {
    try render(
      InteractiveItemView(item: item, defaultStyle: defaultStyle)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .environment(runtime)
        .environment(ActionRunner())
    )
  }

  private func render<Content: View>(_ content: Content) throws -> NSBitmapImageRep {
    let renderer = ImageRenderer(
      content:
        content
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, .leftToRight)
        .fixedSize()
    )
    renderer.scale = 1
    return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
  }
}
