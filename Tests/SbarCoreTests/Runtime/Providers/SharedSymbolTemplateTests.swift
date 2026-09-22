import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
@MainActor
struct SharedSymbolTemplateTests {
  @Test(
    "presentation(for:): conditional symbols follow state while ordinary templates retain defaults"
  )
  func conditional() {
    let runtime = ProviderRuntime()
    var item = Item(
      id: "battery",
      type: .battery,
      text: "{{#charging}}{{symbol}}{{/charging}}{{percentage}}%"
    )
    runtime.updateWidgetState(
      .battery(percentage: 50, charging: true, pluggedIn: true),
      for: .battery
    )

    #expect(runtime.presentation(for: item)?.symbol != nil)
    #expect(runtime.presentation(for: item)?.text == "50%")

    runtime.updateWidgetState(
      .battery(percentage: 50, charging: false, pluggedIn: false),
      for: .battery
    )

    #expect(runtime.presentation(for: item)?.symbol == nil)

    item.text = "{{percentage}}%"

    #expect(runtime.presentation(for: item)?.symbol != nil)

    item.text = "{{symbol}}"

    #expect(runtime.presentation(for: item)?.text == "")
    #expect(runtime.presentation(for: item)?.symbol != nil)

    item.battery = BatteryConfiguration(showSymbol: false)

    #expect(runtime.presentation(for: item)?.symbol == nil)
  }

  @Test("presentation(for:): explicit glyphs remain native and repeated tags do not duplicate them")
  func glyph() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "label",
      type: .text,
      text: "{{symbol}}Hello{{symbol}}",
      symbol: .glyph("S", font: "Menlo", size: 24)
    )
    let presentation = runtime.presentation(for: item)

    #expect(presentation?.text == "Hello")
    #expect(presentation?.symbol == item.symbol)
    #expect(presentation?.segments.isEmpty == true)
  }
}
