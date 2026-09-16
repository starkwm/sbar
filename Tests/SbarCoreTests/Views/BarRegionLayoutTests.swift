import Foundation
import Testing

@testable import SbarCore

@Suite("BarRegionLayout")
struct BarRegionLayoutTests {
  @Test("vertical regions run top to bottom and centre on the available height")
  func verticalRegions() {
    let bounds = CGRect(x: 8, y: 12, width: 48, height: 300)
    let frames = BarRegionLayout.frames(
      in: bounds,
      hasCenter: true,
      notch: CGRect(x: 10, y: 0, width: 20, height: 20),
      isVertical: true
    )
    #expect(
      frames == [
        CGRect(x: 8, y: 12, width: 48, height: 90),
        CGRect(x: 8, y: 112, width: 48, height: 100),
        CGRect(x: 8, y: 222, width: 48, height: 90),
      ]
    )
    let noCenter = BarRegionLayout.frames(
      in: bounds,
      hasCenter: false,
      notch: nil,
      isVertical: true
    )
    #expect(noCenter.map(\.height) == [150, 0, 150])
    for height in [0.0, 1.0, 10.0] {
      let small = BarRegionLayout.frames(
        in: CGRect(x: 0, y: 0, width: 32, height: height),
        hasCenter: true,
        notch: nil,
        isVertical: true
      )
      #expect(small.allSatisfy { $0.minY >= 0 && $0.maxY <= height && $0.height >= 0 })
    }
  }

  @Test("BarRegionLayout.lengths: leaves equal sides around wide center content")
  func lengthsLeaveEqualSidesAroundWideCenter() {
    #expect(BarRegionLayout.lengths(available: 300, centerIdeal: 500) == [90, 100, 90])
  }

  @Test("BarRegionLayout.lengths: gives empty center space to the sides")
  func lengthsGiveEmptyCenterSpaceToSides() {
    #expect(BarRegionLayout.lengths(available: 300, centerIdeal: 0) == [150, 0, 150])
  }

  @Test(
    "BarRegionLayout.lengths: keeps narrow layouts nonnegative and within bounds",
    arguments: [0.0, 1.0, 10.0, 20.0]
  )
  func lengthsKeepNarrowLayoutsWithinBounds(width: Double) {
    let lengths = BarRegionLayout.lengths(available: width, centerIdeal: 100)

    #expect(lengths.allSatisfy { $0 >= 0 })
    #expect(lengths.reduce(0, +) <= width)
    #expect(lengths[0] == lengths[2])
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
