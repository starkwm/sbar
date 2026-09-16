import AppKit
import SwiftUI
import Testing

@testable import SbarCore

@Suite("ItemStyleModifier")
@MainActor
struct ItemStyleModifierTests {
  @Test("group child styles override theme padding while preserving child overrides")
  func groupChildStyles() throws {
    let theme = ItemStyle(fontSize: 20, horizontalPadding: 8)
    var group = Item(
      id: "group",
      type: .group,
      children: (0..<3).map { Item(id: "symbol-\($0)", type: .text, symbol: "star.fill") },
      itemSpacing: 2
    )
    let original = try render(group, defaultStyle: theme)
    group.childStyle = ItemStyle(horizontalPadding: 0)
    let compact = try render(group, defaultStyle: theme)
    #expect(original.pixelsWide - compact.pixelsWide == 48)
    #expect(original.pixelsHigh == compact.pixelsHigh)
    group.children?[0].style = ItemStyle(horizontalPadding: 3)
    #expect(try render(group, defaultStyle: theme).pixelsWide == compact.pixelsWide + 6)
    group.childStyle = nil
    for index in 0..<3 {
      group.children?[index].style = ItemStyle(horizontalPadding: 0)
    }
    #expect(try render(group, defaultStyle: theme).pixelsWide == compact.pixelsWide)
  }

  @Test("Global and per-item font families render with the resolved size and weight")
  func fontFamilies() throws {
    let theme = ItemStyle(fontFamily: "Menlo", fontSize: 24, fontWeight: .bold)
    var item = Item(id: "text", type: .text, text: "iiiiiiii")
    let inherited = try render(item, defaultStyle: theme)
    let expected = try render(Text("iiiiiiii").font(.custom("Menlo", size: 24).weight(.bold)))
    #expect(inherited.pixelsWide == expected.pixelsWide)
    #expect(inherited.pixelsHigh == expected.pixelsHigh)
    item.style = ItemStyle(fontFamily: "Helvetica Neue")
    let overridden = try render(item, defaultStyle: theme)
    let expectedOverride = try render(
      Text("iiiiiiii").font(.custom("Helvetica Neue", size: 24).weight(.bold))
    )
    #expect(overridden.pixelsWide == expectedOverride.pixelsWide)
    #expect(overridden.pixelsHigh == expectedOverride.pixelsHigh)
    #expect(overridden.pixelsWide != inherited.pixelsWide)
  }

  @Test("the default hover highlight remains visible over an opaque rounded background")
  func defaultHover() throws {
    let style = ItemStyle(background: "#0000FF", cornerRadius: 8)
    let content = Color.clear.frame(width: 40, height: 24)
    let normal = try render(content.modifier(ItemStyleModifier(style: style)))
    let hovered = try render(content.modifier(ItemStyleModifier(style: style, hovering: true)))
    let center = try #require(hovered.colorAt(x: 20, y: 12)?.usingColorSpace(.deviceRGB))
    #expect(center.blueComponent > 0.8)
    #expect(center.blueComponent < 0.99)
    #expect(center.alphaComponent == 1)
    #expect(normal.colorAt(x: 20, y: 12)?.usingColorSpace(.deviceRGB)?.blueComponent == 1)
    #expect(hovered.colorAt(x: 0, y: 0)?.alphaComponent == 0)
    #expect(hovered.pixelsWide == normal.pixelsWide)
    #expect(hovered.pixelsHigh == normal.pixelsHigh)
  }

  @Test("hover tint and background replace normal colours without changing the shape")
  func hoverColours() throws {
    let style = ItemStyle(
      tint: "#0000FF",
      background: "#00FF00",
      hoverTint: "#FF0000",
      hoverBackground: "#0000FF",
      horizontalPadding: 10,
      verticalPadding: 8,
      cornerRadius: 8
    )
    let content = Rectangle().frame(width: 10, height: 10)
    let normal = try render(content.modifier(ItemStyleModifier(style: style)))
    let hovered = try render(content.modifier(ItemStyleModifier(style: style, hovering: true)))
    #expect(normal.colorAt(x: 15, y: 13)?.usingColorSpace(.deviceRGB)?.blueComponent == 1)
    #expect(hovered.colorAt(x: 15, y: 13)?.usingColorSpace(.deviceRGB)?.redComponent == 1)
    #expect((normal.colorAt(x: 2, y: 13)?.usingColorSpace(.deviceRGB)?.greenComponent ?? 0) > 0.95)
    #expect(hovered.colorAt(x: 2, y: 13)?.usingColorSpace(.deviceRGB)?.blueComponent == 1)
    #expect(hovered.colorAt(x: 0, y: 0)?.alphaComponent == 0)
    #expect(hovered.pixelsWide == normal.pixelsWide)
    #expect(hovered.pixelsHigh == normal.pixelsHigh)
  }

  @Test("explicit transparent hover backgrounds replace the normal background")
  func transparentHoverBackground() throws {
    let style = ItemStyle(
      background: "#0000FF",
      hoverBackground: "#00000000",
      horizontalPadding: 16,
      verticalPadding: 8,
      cornerRadius: 8
    )
    let image = try render(
      Rectangle().fill(.white).frame(width: 8, height: 8)
        .modifier(ItemStyleModifier(style: style, hovering: true))
    )
    #expect(image.colorAt(x: 8, y: 12)?.alphaComponent == 0)
    #expect(image.colorAt(x: 20, y: 12)?.alphaComponent == 1)
  }

  @Test("fixed widths include symbols and padding and survive changing labels")
  func fixedWidths() throws {
    let style = ItemStyle(horizontalPadding: 8, minWidth: 200, width: 80)
    for label in ["9%", "100%", "A much longer application name that must truncate"] {
      let item = Item(id: "item", type: .text, text: label, symbol: "star.fill", style: style)
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
      text: "9%",
      symbol: "star.fill",
      style: ItemStyle(horizontalPadding: 8, minWidth: 100)
    )
    #expect(try render(item).pixelsWide == 100)
    item.text = "100%"
    #expect(try render(item).pixelsWide == 100)
    item.text = "A much longer application name that needs more space"
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
