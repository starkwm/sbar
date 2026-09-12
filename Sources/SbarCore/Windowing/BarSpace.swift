import AppKit
import OSLog

@MainActor
final class BarSpace {
  struct Access {
    let create: () -> UInt64?
    let addWindow: (CGWindowID, UInt64) -> Void
    let destroy: (UInt64) -> Void
  }

  private static let logger = Logger(subsystem: "com.starkwm.sbar", category: "windowing")

  // Keep SkyLight loaded for the lifetime of the captured function pointers.
  private static let systemAccess: Access? = {
    guard
      let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        RTLD_LAZY | RTLD_LOCAL
      )
    else { return nil }

    guard let connectionSymbol = dlsym(handle, "SLSMainConnectionID"),
      let createSymbol = dlsym(handle, "SLSSpaceCreate"),
      let levelSymbol = dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
      let showSymbol = dlsym(handle, "SLSShowSpaces"),
      let addSymbol = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces"),
      let hideSymbol = dlsym(handle, "SLSHideSpaces"),
      let destroySymbol = dlsym(handle, "SLSSpaceDestroy")
    else {
      dlclose(handle)
      return nil
    }

    let connection = unsafeBitCast(connectionSymbol, to: (@convention(c) () -> Int32).self)
    let create = unsafeBitCast(
      createSymbol,
      to: (@convention(c) (Int32, Int32, CFDictionary?) -> UInt64).self
    )
    let setLevel = unsafeBitCast(
      levelSymbol,
      to: (@convention(c) (Int32, UInt64, Int32) -> Void).self
    )
    let show = unsafeBitCast(
      showSymbol,
      to: (@convention(c) (Int32, CFArray) -> Void).self
    )
    let add = unsafeBitCast(
      addSymbol,
      to: (@convention(c) (Int32, UInt64, CFArray, Int32) -> Void).self
    )
    let hide = unsafeBitCast(
      hideSymbol,
      to: (@convention(c) (Int32, CFArray) -> Void).self
    )
    let destroy = unsafeBitCast(
      destroySymbol,
      to: (@convention(c) (Int32, UInt64) -> Void).self
    )

    return Access(
      create: {
        let cid = connection()
        guard cid != 0 else { return nil }

        // SketchyBar uses flag 1 and absolute level 0 for a Space that stays
        // visible throughout desktop transitions. Panel levels still apply.
        // https://github.com/FelixKratz/SketchyBar/blob/master/src/window.c
        let space = create(cid, 1, nil)
        guard space != 0 else { return nil }
        // These operations are asynchronous and return void on macOS 26.
        // Reading a CGError return value here would read an undefined register.
        setLevel(cid, space, 0)
        show(cid, [NSNumber(value: space)] as CFArray)
        return space
      },
      addWindow: { window, space in
        // 0x7 removes membership in the ordinary Spaces as it adds our Space.
        add(connection(), space, [NSNumber(value: window)] as CFArray, 0x7)
      },
      destroy: { space in
        let cid = connection()
        hide(cid, [NSNumber(value: space)] as CFArray)
        destroy(cid, space)
      }
    )
  }()

  private let access: Access?
  private var spaceID: UInt64?
  private var reportedFailure = false

  init(access: Access? = BarSpace.systemAccess) {
    self.access = access
  }

  @discardableResult
  func addWindow(_ windowNumber: Int) -> Bool {
    guard let window = CGWindowID(exactly: windowNumber), window != 0 else { return false }
    guard let access else { return fallback() }
    if spaceID == nil { spaceID = access.create() }
    guard let spaceID else { return fallback() }
    access.addWindow(window, spaceID)
    return true
  }

  // Close all panels before destroying their Space.
  func stop() {
    if let spaceID { access?.destroy(spaceID) }
    spaceID = nil
  }

  private func fallback() -> Bool {
    if !reportedFailure {
      Self.logger.warning("Persistent bar Space unavailable; using AppKit Spaces behavior")
      reportedFailure = true
    }
    return false
  }
}
