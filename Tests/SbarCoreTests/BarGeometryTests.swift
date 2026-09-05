import Foundation
import Testing

@testable import SbarCore

@Suite("Bar geometry")
struct BarGeometryTests {
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

  @Test("BarPlacement.frame: clamps height to the available display height")
  func frameClampsHeightToDisplay() {
    let visible = CGRect(x: 0, y: 0, width: 100, height: 24)

    #expect(
      BarPlacement.frame(screenFrame: visible, visibleFrame: visible, settings: .init()) == visible
    )
  }

  @Test("BarRegionLayout.widths: leaves equal sides around wide center content")
  func widthsLeaveEqualSidesAroundWideCenter() {
    #expect(BarRegionLayout.widths(available: 300, centerIdeal: 500) == [90, 100, 90])
  }

  @Test("BarRegionLayout.widths: gives empty center space to the sides")
  func widthsGiveEmptyCenterSpaceToSides() {
    #expect(BarRegionLayout.widths(available: 300, centerIdeal: 0) == [150, 0, 150])
  }

  @Test(
    "BarRegionLayout.widths: keeps narrow layouts nonnegative and within bounds",
    arguments: [0.0, 1.0, 10.0, 20.0]
  )
  func widthsKeepNarrowLayoutsWithinBounds(width: Double) {
    let widths = BarRegionLayout.widths(available: width, centerIdeal: 100)

    #expect(widths.allSatisfy { $0 >= 0 })
    #expect(widths.reduce(0, +) <= width)
    #expect(widths[0] == widths[2])
  }

  @Test("BarRegionLayout.frames: excludes the notch on a top-edge bar")
  func framesExcludeNotchOnTopEdgeBar() throws {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    let visible = CGRect(x: 0, y: 0, width: 1710, height: 1074)
    let panel = BarPlacement.frame(screenFrame: screen, visibleFrame: visible, settings: .init())

    #expect(panel == CGRect(x: 0, y: 1080, width: 1710, height: 32))

    let notch = try #require(
      BarPlacement.notch(
        screenFrame: screen,
        leftArea: CGRect(x: 0, y: 1074, width: 751, height: 38),
        rightArea: CGRect(x: 960, y: 1074, width: 750, height: 38),
        panelFrame: panel
      )
    )

    #expect(notch == CGRect(x: 751, y: 0, width: 209, height: 32))

    let frames = BarRegionLayout.frames(
      in: CGRect(x: 0, y: 0, width: 1710, height: 32),
      hasCenter: true,
      notch: notch
    )

    #expect(frames.allSatisfy { !$0.intersects(notch) })
    #expect(frames[1].minX > notch.maxX)
    #expect(frames[1].maxX < frames[2].minX)
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
