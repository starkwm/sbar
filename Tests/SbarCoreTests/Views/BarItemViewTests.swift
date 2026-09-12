import AppKit
import SwiftUI
import Testing

@testable import SbarCore

@Suite("BarItemView")
@MainActor
struct BarItemViewTests {
  @Test("a hover tint overrides individual provider segment colours")
  func segmentTintOverride() throws {
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
    var item = Item(
      id: "spaces",
      type: .spaces,
      spaces: SpacesConfiguration(
        format: .list,
        tints: SpacesTints(active: "#FF0000", inactive: "#00FF00"),
        showSymbol: false
      )
    )
    let normal = try render(BarItemView(configuration: item).environment(runtime))
    let hovered = try render(
      BarItemView(configuration: item, tintOverride: "#0000FF").environment(runtime)
    )
    item.spaces?.tints = SpacesTints(active: "#0000FF", inactive: "#0000FF")
    let expected = try render(BarItemView(configuration: item).environment(runtime))
    #expect(hovered == expected)
    #expect(hovered != normal)
  }

  @Test(
    "item symbols render on the requested side, including the default",
    arguments: [nil, .left, .right] as [ItemSymbolPosition?],
    [ItemSymbol.system("star.fill"), .glyph("S", font: "Menlo", size: 24)]
  )
  func itemSymbols(position: ItemSymbolPosition?, symbol: ItemSymbol) throws {
    let runtime = ProviderRuntime()
    var item = Item(id: "text", type: .text, text: "Status", symbol: symbol)
    if let position { item.symbolPosition = position }

    try expectRendering(
      item,
      runtime: runtime,
      matches: pair(
        position: position,
        symbol: ItemSymbolView(symbol: symbol, fontSize: 24),
        text: "Status"
      )
    )
  }

  @Test(
    "provider state symbols respect placement and visibility",
    arguments: ItemSymbolPosition.allCases
  )
  func providerSymbols(position: ItemSymbolPosition) throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(
      .battery(percentage: 50, charging: true, pluggedIn: true),
      for: .battery
    )
    var item = Item(id: "battery", type: .battery, symbolPosition: position)

    try expectRendering(
      item,
      runtime: runtime,
      matches: pair(
        position: position,
        symbol: Image(systemName: "battery.100percent.bolt"),
        text: "50%"
      )
    )

    item.battery = BatteryConfiguration(showSymbol: false)
    try expectRendering(item, runtime: runtime, matches: Text("50%").monospacedDigit())
    item.text = ""
    item.battery?.showSymbol = true
    try expectRendering(
      item,
      runtime: runtime,
      matches: Image(systemName: "battery.100percent.bolt")
    )
  }

  @Test(
    "segment order stays download then upload for both positions",
    arguments: ItemSymbolPosition.allCases
  )
  func segments(position: ItemSymbolPosition) throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(
      .throughput(ThroughputState(histories: ["en0": [.init(download: 1024, upload: 512)]])),
      for: .throughput
    )
    var item = Item(
      id: "throughput",
      type: .throughput,
      symbolPosition: position,
      throughput: ThroughputConfiguration(
        symbols: ThroughputSymbols(font: "Menlo", size: 24, upload: .glyph("U"))
      )
    )

    // A flat reference catches reversing all segments or moving both symbols to an edge.
    let expected = HStack(spacing: 4) {
      if position == .left {
        Image(systemName: "arrow.down")
        Text("1 KiB/s").monospacedDigit()
        Text("U").font(.custom("Menlo", size: 24))
        Text("512 B/s").monospacedDigit()
      } else {
        Text("1 KiB/s").monospacedDigit()
        Image(systemName: "arrow.down")
        Text("512 B/s").monospacedDigit()
        Text("U").font(.custom("Menlo", size: 24))
      }
    }
    try expectRendering(
      item,
      runtime: runtime,
      matches: expected.foregroundColor(nil).fontWeight(nil)
    )

    // An item-level override sits beside all the rates, which retain their order.
    item.symbol = "star.fill"
    let rates = HStack(spacing: 4) {
      Text("1 KiB/s").monospacedDigit()
      Text("512 B/s").monospacedDigit()
    }
    .foregroundColor(nil)
    .fontWeight(nil)
    let overridden = HStack(spacing: 4) {
      if position == .left { Image(systemName: "star.fill") }
      rates
      if position == .right { Image(systemName: "star.fill") }
    }
    try expectRendering(item, runtime: runtime, matches: overridden)
  }

  @Test(
    "application icons and fallback symbols respect placement",
    arguments: ItemSymbolPosition.allCases
  )
  func applicationIcons(position: ItemSymbolPosition) throws {
    let runtime = ProviderRuntime()
    let icon = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { bounds in
      NSColor.systemRed.setFill()
      NSBezierPath(ovalIn: bounds).fill()
      return true
    }
    runtime.updateFrontApplication(.init(name: "Example", icon: icon))
    let item = Item(
      id: "app",
      type: .frontApplication,
      symbol: "app",
      symbolPosition: position,
      frontApplication: FrontApplicationConfiguration(showIcon: true)
    )
    let image = Image(nsImage: icon)
      .renderingMode(.original)
      .resizable()
      .scaledToFit()
      .frame(width: 24, height: 24)
    try expectRendering(
      item,
      runtime: runtime,
      matches: pair(position: position, symbol: image, text: "Example")
    )

    var templated = item
    templated.text = "App: {{name}}"
    try expectRendering(
      templated,
      runtime: runtime,
      matches: pair(position: position, symbol: image, text: "App: Example")
    )

    runtime.updateFrontApplication(.init(name: "Example", icon: nil))
    try expectRendering(
      item,
      runtime: runtime,
      matches: pair(position: position, symbol: Image(systemName: "app"), text: "Example")
    )
  }

  private func pair<Symbol: View>(position: ItemSymbolPosition?, symbol: Symbol, text: String)
    -> some View
  {
    HStack(spacing: 4) {
      if position != .right { symbol }
      Text(text).monospacedDigit()
      if position == .right { symbol }
    }
  }

  private func expectRendering<Expected: View>(
    _ item: Item,
    runtime: ProviderRuntime,
    matches expected: Expected
  ) throws {
    let actual = try render(
      BarItemView(configuration: item, symbolFontSize: 24).environment(runtime)
    )
    let reference = try render(expected)
    #expect(actual == reference)
  }

  private func render<Content: View>(_ content: Content) throws -> Data {
    let renderer = ImageRenderer(
      content:
        content
        .font(.system(size: 24))
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, .leftToRight)
        .fixedSize()
        .background(.white)
    )
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    )
  }
}
