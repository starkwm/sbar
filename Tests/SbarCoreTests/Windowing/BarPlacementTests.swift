import Foundation
import Testing

@testable import SbarCore

@Suite("BarPlacement")
struct BarPlacementTests {
  @Test(
    "frame: side bars can reach the physical top edge while respecting the Dock",
    arguments: [BarPosition.left, .right]
  )
  func extendedTopEdge(position: BarPosition) throws {
    let screen = CGRect(x: -1440, y: -200, width: 1440, height: 900)
    let visible = CGRect(x: -1380, y: -160, width: 1380, height: 836)
    var settings = try JSONDecoder().decode(
      BarSettings.self,
      from: Data(#"{"extendToTopEdge":true}"#.utf8)
    )
    settings.position = position
    let frame = BarPlacement.frame(screenFrame: screen, visibleFrame: visible, settings: settings)

    #expect(frame.maxY == screen.maxY)
    #expect(frame.minY == visible.minY)

    let expectedX: CGFloat = position == .left ? visible.minX : visible.maxX - settings.width

    #expect(frame.minX == expectedX)

    settings.margin = .init(top: 8, bottom: 12)
    let inset = BarPlacement.frame(screenFrame: screen, visibleFrame: visible, settings: settings)

    #expect(inset.maxY == screen.maxY - 8)
    #expect(inset.minY == visible.minY + 12)
    #expect(
      try JSONDecoder().decode(BarSettings.self, from: Data("{}".utf8)).extendToTopEdge == false
    )

    for horizontal in [BarPosition.top, .bottom] {
      settings.position = horizontal
      let enabled = BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: visible,
        settings: settings
      )
      settings.extendToTopEdge = false

      #expect(
        enabled
          == BarPlacement.frame(screenFrame: screen, visibleFrame: visible, settings: settings)
      )

      settings.extendToTopEdge = true
    }
  }

  @Test(
    "frame: side bars respect the usable frame, independent margins and display origins",
    arguments: [BarPosition.left, .right]
  )
  func verticalPlacement(position: BarPosition) {
    let screen = CGRect(x: -1440, y: -200, width: 1440, height: 900)
    // A left Dock and top menu bar reduce the usable rectangle.
    let visible = CGRect(x: -1380, y: -200, width: 1380, height: 876)
    let frame = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: visible,
      settings: .init(
        position: position,
        height: 96,
        width: 48,
        margin: .init(top: 10, bottom: 20, left: 6, right: 8)
      )
    )

    #expect(frame == CGRect(x: position == .left ? -1374 : -56, y: -180, width: 48, height: 846))

    let rightDock = CGRect(x: -1440, y: -200, width: 1380, height: 876)
    let besideDock = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: rightDock,
      settings: .init(position: position, width: 48)
    )

    #expect(besideDock.minX == (position == .left ? -1440 : -108))
    #expect(besideDock.maxY == rightDock.maxY)
  }

  @Test(
    "frame: side bars clamp width and excessive margins",
    arguments: [BarPosition.left, .right]
  )
  func verticalClamping(position: BarPosition) {
    let screen = CGRect(x: 100, y: -200, width: 24, height: 100)

    #expect(
      BarPlacement.frame(
        screenFrame: screen,
        visibleFrame: screen,
        settings: .init(position: position, width: 96)
      ) == screen
    )

    let frame = BarPlacement.frame(
      screenFrame: screen,
      visibleFrame: screen,
      settings: .init(
        position: position,
        margin: .init(top: 4096, bottom: 4096, left: 4096, right: 4096)
      )
    )

    #expect(frame == CGRect(x: 123, y: -200, width: 1, height: 1))
  }

  @Test("BarPlacement.frame: uses the physical top edge and respects the Dock at the bottom")
  func screenEdges() {
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
  func notchCoordinates() {
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
