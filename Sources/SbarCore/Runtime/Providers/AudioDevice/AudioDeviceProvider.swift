import CoreAudio
import Foundation

@MainActor
final class AudioDeviceProvider {
  private let access: any AudioDeviceAccess
  private let retryInterval: Duration
  private var observers: [AudioDeviceProperty: @MainActor () -> Void] = [:]
  private var update: (@MainActor (AudioDeviceState) -> Void)?
  private var refreshTask: Task<Void, Never>?
  private var generation = UUID()

  init(
    access: any AudioDeviceAccess = SystemAudioDeviceAccess(),
    retryInterval: Duration = .seconds(2)
  ) {
    self.access = access
    self.retryInterval = retryInterval
  }

  func start(update: @escaping @MainActor (AudioDeviceState) -> Void) {
    stop()
    self.update = update
    refresh()
  }

  func stop() {
    generation = UUID()
    refreshTask?.cancel()
    refreshTask = nil
    removeObservers()
    update = nil
  }

  private func refresh() {
    guard let update else { return }

    var required = Set(AudioDeviceProperty.systemProperties)
    var observing = true

    for property in required {
      if !observe(property) { observing = false }
    }

    let state: AudioDeviceState

    if observing {
      state = AudioDeviceState(
        output: read(.output, required: &required),
        input: read(.input, required: &required)
      )
    } else {
      state = AudioDeviceState()
    }
    for property in observers.keys.filter({ !required.contains($0) }) {
      observers.removeValue(forKey: property)?()
    }

    update(state)

    if state.output.status == .unavailable || state.input.status == .unavailable {
      scheduleRefresh(after: retryInterval)
    }
  }

  private func read(_ kind: AudioDeviceKind, required: inout Set<AudioDeviceProperty>)
    -> AudioDeviceEndpoint
  {
    let selector =
      kind == .input
      ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    guard let device = access.readUInt32(.init(selector: selector)) else { return .init() }
    guard device != kAudioObjectUnknown else { return .init(status: .disconnected) }

    let alive = AudioDeviceProperty(object: device, selector: kAudioDevicePropertyDeviceIsAlive)
    let name = AudioDeviceProperty(object: device, selector: kAudioObjectPropertyName)
    required.formUnion([alive, name])
    // Subscribe before reading so a change during the read causes another refresh.
    guard observe(alive), observe(name), let isAlive = access.readUInt32(alive) else {
      return .init()
    }
    guard isAlive != 0 else { return .init(status: .disconnected) }
    guard let value = access.readName(device) else { return .init() }

    return AudioDeviceEndpoint(status: .available, id: device, name: value)
  }

  private func observe(_ property: AudioDeviceProperty) -> Bool {
    if observers[property] != nil { return true }

    let generation = generation
    guard
      let cancel = access.observe(
        property,
        changed: { [weak self] in
          guard let self, self.generation == generation, self.observers[property] != nil else {
            return
          }

          if property.selector == kAudioHardwarePropertyServiceRestarted {
            // Core Audio discards device IDs and listeners when its service restarts.
            self.generation = UUID()
            self.removeObservers()
          }

          self.scheduleRefresh()
        }
      )
    else { return false }

    observers[property] = cancel

    return true
  }

  private func scheduleRefresh(after delay: Duration = .milliseconds(50)) {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      do { try await Task.sleep(for: delay) } catch { return }

      guard let self, !Task.isCancelled else { return }

      self.refreshTask = nil
      self.refresh()
    }
  }

  private func removeObservers() {
    let cancellations = Array(observers.values)
    observers.removeAll()

    for cancel in cancellations { cancel() }
  }
}

struct AudioDeviceProperty: Hashable, Sendable {
  static let systemProperties: [Self] = [
    .init(selector: kAudioHardwarePropertyDefaultOutputDevice),
    .init(selector: kAudioHardwarePropertyDefaultInputDevice),
    .init(selector: kAudioHardwarePropertyDevices),
    .init(selector: kAudioHardwarePropertyServiceRestarted),
  ]

  var object: AudioObjectID = AudioObjectID(kAudioObjectSystemObject)
  var selector: AudioObjectPropertySelector

  var address: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }
}

@MainActor
protocol AudioDeviceAccess {
  func readUInt32(_ property: AudioDeviceProperty) -> UInt32?
  func readName(_ device: AudioObjectID) -> String?
  func observe(_ property: AudioDeviceProperty, changed: @escaping @MainActor @Sendable () -> Void)
    -> (@MainActor () -> Void)?
}

@MainActor
private final class SystemAudioDeviceAccess: AudioDeviceAccess {
  func readUInt32(_ property: AudioDeviceProperty) -> UInt32? {
    var address = property.address
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard
      AudioObjectGetPropertyData(property.object, &address, 0, nil, &size, &value) == noErr,
      size == MemoryLayout<UInt32>.size
    else { return nil }

    return value
  }

  func readName(_ device: AudioObjectID) -> String? {
    var address = AudioDeviceProperty(object: device, selector: kAudioObjectPropertyName).address
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard
      AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr,
      let value
    else { return nil }

    // kAudioObjectPropertyName transfers ownership of its CFString to the caller.
    return value.takeRetainedValue() as String
  }

  func observe(_ property: AudioDeviceProperty, changed: @escaping @MainActor @Sendable () -> Void)
    -> (@MainActor () -> Void)?
  {
    var address = property.address
    let listener: AudioObjectPropertyListenerBlock = { @Sendable _, _ in
      Task { @MainActor in changed() }
    }
    guard AudioObjectAddPropertyListenerBlock(property.object, &address, .main, listener) == noErr
    else { return nil }

    return {
      var address = property.address
      AudioObjectRemovePropertyListenerBlock(property.object, &address, .main, listener)
    }
  }
}
