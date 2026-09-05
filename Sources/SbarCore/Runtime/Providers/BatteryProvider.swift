import Foundation
import IOKit.ps

@MainActor
final class BatteryProvider {
  private var source: CFRunLoopSource?
  private var update: (@MainActor (WidgetState) -> Void)?

  func start(update: @escaping @MainActor (WidgetState) -> Void) {
    stop()
    self.update = update
    refresh()

    source = IOPSNotificationCreateRunLoopSource(
      { context in
        guard let context else { return }

        let provider = Unmanaged<BatteryProvider>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { provider.refresh() }
      },
      Unmanaged.passUnretained(self).toOpaque()
    ).takeRetainedValue()
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
  }

  func stop() {
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    source = nil
    update = nil
  }

  private func refresh() {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
    else { return }

    for source in sources {
      guard
        let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
          as? [String: Any],
        let capacity = info[kIOPSCurrentCapacityKey] as? Int,
        let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0
      else { continue }

      let pluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
      let charging = info[kIOPSIsChargingKey] as? Bool ?? false
      update?(
        .battery(
          percentage: min(100, max(0, capacity * 100 / maximum)),
          charging: charging,
          pluggedIn: pluggedIn
        )
      )
      return
    }

    update?(.battery(percentage: nil, charging: false, pluggedIn: true))
  }
}
