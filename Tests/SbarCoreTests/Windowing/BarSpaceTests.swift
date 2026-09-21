import AppKit
import Testing

@testable import SbarCore

@Suite("BarSpace")
@MainActor
struct BarSpaceTests {
  @Test("shares one Space across panels and reattaches after AppKit updates")
  func sharedSpace() {
    let system = TestBarSpaceAccess()
    let space = BarSpace(access: system.access)

    #expect(system.creations == 0)
    #expect(space.addWindow(10))
    #expect(space.addWindow(20))
    #expect(space.addWindow(10))
    #expect(system.creations == 1)
    #expect(system.windows == [10, 20, 10])
    #expect(system.spaces == [42, 42, 42])

    space.stop()
    space.stop()

    #expect(system.destroyed == [42])
  }

  @Test("missing APIs and invalid window numbers leave AppKit in control")
  func unavailable() {
    let unavailable = BarSpace(access: nil)

    #expect(!unavailable.addWindow(10))

    unavailable.stop()

    let system = TestBarSpaceAccess()
    let space = BarSpace(access: system.access)

    for number in [-1, 0, Int(UInt32.max) + 1] {
      #expect(!space.addWindow(number))
    }

    #expect(system.creations == 0)
    #expect(system.windows.isEmpty)
  }

  @Test("creation failures can recover on the next panel update")
  func creationFailure() {
    let system = TestBarSpaceAccess()
    system.createdSpace = nil
    let space = BarSpace(access: system.access)

    #expect(!space.addWindow(10))
    #expect(system.windows.isEmpty)

    system.createdSpace = 43

    #expect(space.addWindow(10))
    #expect(system.spaces == [43])

    space.stop()

    #expect(system.destroyed == [43])
  }

  @Test("starting again after stop creates a fresh Space")
  func restart() {
    let system = TestBarSpaceAccess()
    let space = BarSpace(access: system.access)

    #expect(space.addWindow(10))

    space.stop()
    system.createdSpace = 43

    #expect(space.addWindow(20))
    #expect(system.spaces == [42, 43])

    space.stop()

    #expect(system.destroyed == [42, 43])
  }
}

@MainActor
private final class TestBarSpaceAccess {
  var createdSpace: UInt64? = 42
  var creations = 0
  var windows: [CGWindowID] = []
  var spaces: [UInt64] = []
  var destroyed: [UInt64] = []

  var access: BarSpace.Access {
    BarSpace.Access(
      create: {
        self.creations += 1

        return self.createdSpace
      },
      addWindow: { window, space in
        self.windows.append(window)
        self.spaces.append(space)
      },
      destroy: { self.destroyed.append($0) }
    )
  }
}
