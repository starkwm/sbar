import Foundation
import Testing

@testable import SbarCore

@Suite("BarWindowLayout")
struct BarWindowLayoutTests {
  @Test(
    "side shadows preserve content coordinates and pass clicks through the fade",
    arguments: [BarPosition.left, .right]
  )
  func verticalShadows(position: BarPosition) {
    let screen = CGRect(x: -100, y: -200, width: 900, height: 700)
    let bar = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: screen,
      settings: .init(position: position, width: 48)
    )
    let layout = BarWindowLayout(
      screenFrame: screen,
      barFrame: bar,
      position: position,
      shadow: true,
      cornerRadius: 0
    )
    #expect(layout.shadowExtent == 16)
    #expect(!layout.hasNativeShadow)
    #expect(layout.frame.width == 64)
    #expect(layout.frame.height == bar.height)
    #expect(
      CGRect(
        x: layout.frame.minX + layout.contentFrame.minX,
        y: layout.frame.maxY - layout.contentFrame.maxY,
        width: layout.contentFrame.width,
        height: layout.contentFrame.height
      ) == bar
    )
    let hit = CGRect(x: 5, y: 10, width: 30, height: 20)
    let fade = CGPoint(x: position == .left ? 56 : 8, y: 15)
    for passthrough in [false, true] {
      #expect(
        layout.ignoresMouse(at: fade, passingThroughEmptyRegions: passthrough, hitRegions: [hit])
      )
      #expect(
        !layout.ignoresMouse(
          at: CGPoint(x: layout.contentFrame.minX + 10, y: 15),
          passingThroughEmptyRegions: passthrough,
          hitRegions: [hit]
        )
      )
      #expect(
        layout.ignoresMouse(
          at: CGPoint(x: layout.contentFrame.minX + 10, y: 50),
          passingThroughEmptyRegions: passthrough,
          hitRegions: [hit]
        ) == passthrough
      )
    }
    let smallScreen = CGRect(x: 0, y: 0, width: 40, height: 100)
    let smallBar = BarPlacement.frame(
      screenFrame: smallScreen,
      visibleFrame: smallScreen,
      settings: .init(position: position)
    )
    let smallLayout = BarWindowLayout(
      screenFrame: smallScreen,
      barFrame: smallBar,
      position: position,
      shadow: true,
      cornerRadius: 0
    )
    #expect(smallLayout.shadowExtent == 8)
    #expect(smallLayout.frame == smallScreen)
    let disabled = BarWindowLayout(
      screenFrame: screen,
      barFrame: bar,
      position: position,
      shadow: false,
      cornerRadius: 0
    )
    #expect(disabled.frame == bar)
    #expect(disabled.contentFrame.origin == .zero)
    let inset = BarWindowLayout(
      screenFrame: screen,
      barFrame: bar.insetBy(dx: 0, dy: 6),
      position: position,
      shadow: true,
      cornerRadius: 0
    )
    #expect(inset.hasNativeShadow)
    #expect(inset.shadowExtent == 0)
  }

  @Test("square full-width bars cast an edge shadow without moving their content")
  func edgeShadowGeometry() {
    let screen = CGRect(x: -1440, y: 100, width: 1440, height: 900)
    for position in [BarPosition.top, .bottom] {
      let bar = BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: screen,
        settings: .init(position: position)
      )
      let layout = BarWindowLayout(
        screenFrame: screen,
        barFrame: bar,
        position: position,
        shadow: true,
        cornerRadius: 0
      )
      #expect(!layout.hasNativeShadow)
      #expect(layout.shadowExtent == 16)
      #expect(layout.frame.height == bar.height + 16)
      #expect(layout.frame.minX == bar.minX)
      #expect(layout.contentFrame.size == bar.size)
      #expect(layout.position == position)
      let contentOnScreen = CGRect(
        x: layout.frame.minX + layout.contentFrame.minX,
        y: layout.frame.maxY - layout.contentFrame.maxY,
        width: layout.contentFrame.width,
        height: layout.contentFrame.height
      )
      #expect(contentOnScreen == bar)
    }
  }

  @Test("inset and rounded bars keep native shadows, including beside a side Dock")
  func nativeShadowGeometry() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    for (bar, radius) in [
      (CGRect(x: 0, y: 868, width: 1440, height: 32), 12.0),
      (CGRect(x: 6, y: 868, width: 1428, height: 32), 0.0),
      (CGRect(x: 0, y: 868, width: 1434, height: 32), 0.0),
      (CGRect(x: 60, y: 0, width: 1380, height: 32), 0.0),
    ] {
      let layout = BarWindowLayout(
        screenFrame: screen,
        barFrame: bar,
        position: .top,
        shadow: true,
        cornerRadius: radius
      )
      #expect(layout.hasNativeShadow)
      #expect(layout.shadowExtent == 0)
      #expect(layout.frame == bar)
      #expect(layout.contentFrame.origin == .zero)
    }
  }

  @Test("shadow decorations never intercept clicks, and bottom-bar item coordinates stay aligned")
  func hitTesting() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let bar = CGRect(x: 0, y: 0, width: 1440, height: 32)
    let layout = BarWindowLayout(
      screenFrame: screen,
      barFrame: bar,
      position: .bottom,
      shadow: true,
      cornerRadius: 0
    )
    let regions = [CGRect(x: 10, y: 4, width: 80, height: 24)]
    for passthrough in [false, true] {
      #expect(
        layout.ignoresMouse(
          at: CGPoint(x: 20, y: 8),
          passingThroughEmptyRegions: passthrough,
          hitRegions: regions
        )
      )
      #expect(
        !layout.ignoresMouse(
          at: CGPoint(x: 20, y: 24),
          passingThroughEmptyRegions: passthrough,
          hitRegions: regions
        )
      )
      #expect(
        layout.ignoresMouse(
          at: CGPoint(x: 120, y: 24),
          passingThroughEmptyRegions: passthrough,
          hitRegions: regions
        ) == passthrough
      )
    }
  }

  @Test("disabled shadows restore the exact bar frame and small displays clip the decoration")
  func constrainedShadow() {
    let screen = CGRect(x: 0, y: 0, width: 100, height: 40)
    for position in [BarPosition.top, .bottom] {
      let bar = BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: screen,
        settings: .init(position: position)
      )
      let enabled = BarWindowLayout(
        screenFrame: screen,
        barFrame: bar,
        position: position,
        shadow: true,
        cornerRadius: 0
      )
      #expect(enabled.shadowExtent == 8)
      #expect(enabled.frame == screen)
      let disabled = BarWindowLayout(
        screenFrame: screen,
        barFrame: bar,
        position: position,
        shadow: false,
        cornerRadius: 0
      )
      #expect(disabled.frame == bar)
      #expect(disabled.shadowExtent == 0)
      #expect(!disabled.hasNativeShadow)
    }
  }
}
