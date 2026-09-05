import Foundation
import Testing

@testable import SbarCore

@Suite("Foundation geometry")
struct FoundationTests {
  @Test("Top uses the physical edge while bottom respects the Dock")
  func placement() {
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

  @Test("Bar height cannot exceed available display height")
  func smallDisplay() {
    let visible = CGRect(x: 0, y: 0, width: 100, height: 24)
    #expect(
      BarPlacement.frame(screenFrame: visible, visibleFrame: visible, settings: .init()) == visible
    )
  }

  @Test("Wide center content leaves equal nonoverlapping side regions")
  func wideCenter() {
    #expect(BarRegionLayout.widths(available: 300, centerIdeal: 500) == [90, 100, 90])
  }

  @Test("Empty center releases its budget to the sides")
  func emptyCenter() {
    #expect(BarRegionLayout.widths(available: 300, centerIdeal: 0) == [150, 0, 150])
  }

  @Test("Narrow layouts never produce negative widths", arguments: [0.0, 1.0, 10.0, 20.0])
  func narrowLayout(width: Double) {
    let widths = BarRegionLayout.widths(available: width, centerIdeal: 100)
    #expect(widths.allSatisfy { $0 >= 0 })
    #expect(widths.reduce(0, +) <= width)
    #expect(widths[0] == widths[2])
  }

  @Test("Notched display reaches the physical top and excludes the cutout")
  func notch() throws {
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

  @Test("Notch conversion handles offset screens and ignores bottom bars")
  func offsetNotch() {
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
