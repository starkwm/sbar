import Foundation
import Testing

@testable import SbarCore

@Suite("BarPlacement")
struct BarPlacementTests {
  @Test("BarPlacement.frame: uses the physical top edge and respects the Dock at the bottom")
  func frameUsesPhysicalTopEdgeAndRespectsDock() {
    let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
    let visible = CGRect(x: -1440, y: 40, width: 1440, height: 836)

    #expect(
      BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: visible,
        settings: .init(position: .top)
      ) == CGRect(x: -1440, y: 868, width: 1440, height: 32)
    )

    #expect(
      BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: visible,
        settings: .init(position: .bottom)
      ) == CGRect(x: -1440, y: 40, width: 1440, height: 32)
    )
  }

  @Test("BarPlacement.frame: applies independent margins on offset displays")
  func frameAppliesMargins() {
    let screen = CGRect(x: -1440, y: 100, width: 1440, height: 900)
    let visible = CGRect(x: -1440, y: 140, width: 1440, height: 836)
    let margin = BarMargin(top: 44, bottom: 12, left: 20, right: 30)
    #expect(
      BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: visible,
        settings: .init(margin: margin)
      ) == CGRect(x: -1420, y: 924, width: 1390, height: 32)
    )
    #expect(
      BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: visible,
        settings: .init(position: .bottom, margin: margin)
      )
        == CGRect(x: -1420, y: 152, width: 1390, height: 32)
    )
  }

  @Test("BarPlacement.frame: excessive margins retain an on-screen frame")
  func frameClampsMargins() {
    let screen = CGRect(x: 100, y: -200, width: 100, height: 50)
    let frame = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: screen,
      settings: .init(margin: .init(top: 4096, bottom: 4096, left: 4096, right: 4096))
    )
    #expect(frame == CGRect(x: 199, y: -200, width: 1, height: 1))
  }

  @Test("BarPlacement.frame: clamps height to the available display height")
  func frameClampsHeightToDisplay() {
    let visible = CGRect(x: 0, y: 0, width: 100, height: 24)

    #expect(
      BarPlacement.frame(screenFrame: visible, visibleFrame: visible, settings: .init()) == visible
    )
  }

  @Test("BarPlacement.notch: handles offset screens and ignores bottom bars")
  func notchHandlesOffsetScreensAndIgnoresBottomBars() {
    let screen = CGRect(x: -1710, y: 100, width: 1710, height: 1112)
    let left = CGRect(x: -1710, y: 1174, width: 751, height: 38)
    let right = CGRect(x: -750, y: 1174, width: 750, height: 38)
    let top = BarPlacement.frame(screenFrame: screen, visibleFrame: screen, settings: .init())

    #expect(
      BarPlacement.notch(screenFrame: screen, leftArea: left, rightArea: right, panelFrame: top)?
        .minX == 751
    )

    let bottom = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: screen,
      settings: .init(position: .bottom)
    )

    #expect(
      BarPlacement.notch(screenFrame: screen, leftArea: left, rightArea: right, panelFrame: bottom)
        == nil
    )

    #expect(
      BarPlacement.notch(screenFrame: screen, leftArea: nil, rightArea: nil, panelFrame: top) == nil
    )
  }
}
