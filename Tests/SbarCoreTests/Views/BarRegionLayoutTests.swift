import Foundation
import Testing

@testable import SbarCore

@Suite("BarRegionLayout")
struct BarRegionLayoutTests {
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
}
