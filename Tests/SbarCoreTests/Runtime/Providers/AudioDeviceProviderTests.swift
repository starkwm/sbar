import CoreAudio
import Testing

@testable import SbarCore

@Suite("Audio device provider")
@MainActor
struct AudioDeviceProviderTests {
  @Test("default device changes and renames replace only obsolete device listeners")
  func changes() async throws {
    let access = TestAudioDeviceAccess()
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    var states: [AudioDeviceState] = []
    provider.start { states.append($0) }
    #expect(states.last?.output.name == "Speakers")
    #expect(states.last?.input.name == "Microphone")
    #expect(access.observers.count == 8)
    access.values[.init(selector: kAudioHardwarePropertyDefaultOutputDevice)] = 13
    access.values[.init(object: 13, selector: kAudioDevicePropertyDeviceIsAlive)] = 1
    access.names[13] = "Headphones"
    access.emit(.init(selector: kAudioHardwarePropertyDefaultOutputDevice))
    try await Task.sleep(for: .milliseconds(150))
    #expect(states.last?.output.id == 13)
    #expect(states.last?.output.name == "Headphones")
    #expect(access.observers.keys.allSatisfy { $0.object != 11 })
    #expect(access.observers.count == 8)
    #expect(access.installations[.init(object: 12, selector: kAudioObjectPropertyName)] == 1)
    access.names[12] = "Renamed microphone"
    access.emit(.init(object: 12, selector: kAudioObjectPropertyName))
    try await Task.sleep(for: .milliseconds(150))
    #expect(states.last?.input.name == "Renamed microphone")
    #expect(states.count == 3)
  }

  @Test("a shared input and output device uses one set of listeners")
  func sharedDevice() {
    let access = TestAudioDeviceAccess()
    access.values[.init(selector: kAudioHardwarePropertyDefaultInputDevice)] = 11
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    provider.start { state in #expect(state.input == state.output) }
    #expect(access.observers.count == 6)
    #expect(access.installations.values.allSatisfy { $0 == 1 })
  }

  @Test("missing or dead devices differ from failed reads and do not suppress the other direction")
  func missingDevices() async throws {
    let access = TestAudioDeviceAccess()
    let input = AudioDeviceProperty(selector: kAudioHardwarePropertyDefaultInputDevice)
    access.values[input] = kAudioObjectUnknown
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    var state = AudioDeviceState()
    provider.start { state = $0 }
    #expect(state.output.status == .available)
    #expect(state.input.status == .disconnected)
    access.values[input] = nil
    access.emit(input)
    try await Task.sleep(for: .milliseconds(150))
    #expect(state.input.status == .unavailable)
    #expect(state.output.name == "Speakers")
    let alive = AudioDeviceProperty(object: 11, selector: kAudioDevicePropertyDeviceIsAlive)
    access.values[alive] = 0
    access.emit(alive)
    try await Task.sleep(for: .milliseconds(150))
    #expect(state.output.status == .disconnected)
    #expect(state.output.name == nil)
    access.values[alive] = nil
    access.emit(alive)
    try await Task.sleep(for: .milliseconds(150))
    #expect(state.output.status == .unavailable)
  }

  @Test(
    "failed subscriptions and name reads recover without another hardware event",
    arguments: [0, 1, 2]
  )
  func recovery(failure: Int) async throws {
    let access = TestAudioDeviceAccess()
    if failure == 0 {
      access.failures.insert(.init(selector: kAudioHardwarePropertyDefaultOutputDevice))
    } else if failure == 1 {
      access.failures.insert(.init(object: 11, selector: kAudioObjectPropertyName))
    } else {
      access.names[11] = nil
    }
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    var state = AudioDeviceState()
    provider.start { state = $0 }
    #expect(state.output.status == .unavailable)
    access.failures.removeAll()
    access.names[11] = "Speakers"
    try await Task.sleep(for: .milliseconds(2200))
    #expect(state.output.status == .available)
    #expect(state.input.status == .available)
    #expect(access.observers.count == 8)
  }

  @Test("bursts coalesce, stop cancels pending refreshes, and callbacks cannot cross sessions")
  func lifecycle() async throws {
    let access = TestAudioDeviceAccess()
    let property = AudioDeviceProperty(selector: kAudioHardwarePropertyDevices)
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    var updates = 0
    provider.start { _ in updates += 1 }
    let stale = access.observers[property]
    for _ in 0..<5 { access.emit(property) }
    try await Task.sleep(for: .milliseconds(150))
    #expect(updates == 2)
    access.emit(property)
    provider.stop()
    #expect(access.observers.isEmpty)
    stale?()
    try await Task.sleep(for: .milliseconds(100))
    #expect(updates == 2)
    provider.start { _ in updates += 1 }
    let reads = access.reads
    stale?()
    try await Task.sleep(for: .milliseconds(100))
    #expect(access.reads == reads)
    #expect(updates == 3)
  }

  @Test("Core Audio restarts reestablish all listeners and discard callbacks from before the reset")
  func serviceRestart() async throws {
    let access = TestAudioDeviceAccess()
    let property = AudioDeviceProperty(selector: kAudioHardwarePropertyDevices)
    let provider = AudioDeviceProvider(access: access)
    defer { provider.stop() }
    var updates = 0
    provider.start { _ in updates += 1 }
    let stale = access.observers[property]
    access.emit(.init(selector: kAudioHardwarePropertyServiceRestarted))
    #expect(access.observers.isEmpty)
    try await Task.sleep(for: .milliseconds(150))
    #expect(access.observers.count == 8)
    #expect(access.installations.values.allSatisfy { $0 == 2 })
    stale?()
    try await Task.sleep(for: .milliseconds(100))
    #expect(updates == 2)
  }

  @Test("runtime shares monitoring and captures input changes even when output text stays the same")
  func runtime() async throws {
    let access = TestAudioDeviceAccess()
    let runtime = ProviderRuntime(audioDevice: AudioDeviceProvider(access: access))
    defer { runtime.stop() }
    let event = Item(id: "output", type: .audioDevice, refresh: .init(mode: .event))
    var input = Item(
      id: "input",
      type: .audioDevice,
      audioDevice: .init(device: .input),
      refresh: .init(mode: .event)
    )
    let manual = Item(
      id: "manual",
      type: .audioDevice,
      audioDevice: .init(device: .input),
      refresh: .init(mode: .manual)
    )
    let interval = Item(
      id: "interval",
      type: .audioDevice,
      audioDevice: .init(device: .input),
      refresh: .init(mode: .interval, seconds: 3600)
    )
    let configuration = Configuration(
      bar: .init(),
      items: .init(right: [event, input, manual, interval])
    )
    runtime.configure(configuration)
    runtime.configure(configuration)
    #expect(access.installations.values.allSatisfy { $0 == 1 })
    #expect(runtime.presentation(for: manual)?.text == "Microphone")
    access.names[12] = "USB Microphone"
    access.emit(.init(object: 12, selector: kAudioObjectPropertyName))
    try await Task.sleep(for: .milliseconds(150))
    #expect(runtime.sharedValues[.audioDevice] == "Speakers")
    #expect(runtime.presentation(for: event)?.text == "Speakers")
    #expect(runtime.presentation(for: input)?.text == "USB Microphone")
    #expect(runtime.presentation(for: manual)?.text == "Microphone")
    #expect(runtime.presentation(for: interval)?.text == "Microphone")
    runtime.trigger(manual.id)
    runtime.trigger(interval.id)
    #expect(runtime.presentation(for: manual)?.text == "USB Microphone")
    #expect(runtime.presentation(for: interval)?.text == "USB Microphone")
    input.audioDevice?.device = .output
    runtime.configure(
      Configuration(bar: .init(), items: .init(right: [event, input, manual, interval]))
    )
    #expect(runtime.presentation(for: input)?.text == "Speakers")
    #expect(access.installations.values.allSatisfy { $0 == 1 })
    runtime.configure(
      Configuration(
        bar: .init(),
        items: .init(right: [
          Item(id: "disabled", type: .group, enabled: false, children: [event, input])
        ])
      )
    )
    #expect(access.observers.isEmpty)
    runtime.configure(configuration)
    #expect(access.installations.values.allSatisfy { $0 == 2 })
  }
}

@MainActor
private final class TestAudioDeviceAccess: AudioDeviceAccess {
  var values: [AudioDeviceProperty: UInt32] = [
    .init(selector: kAudioHardwarePropertyDefaultOutputDevice): 11,
    .init(selector: kAudioHardwarePropertyDefaultInputDevice): 12,
    .init(object: 11, selector: kAudioDevicePropertyDeviceIsAlive): 1,
    .init(object: 12, selector: kAudioDevicePropertyDeviceIsAlive): 1,
  ]
  var names: [AudioObjectID: String] = [11: "Speakers", 12: "Microphone"]
  var observers: [AudioDeviceProperty: @MainActor @Sendable () -> Void] = [:]
  var installations: [AudioDeviceProperty: Int] = [:]
  var failures = Set<AudioDeviceProperty>()
  var reads = 0

  func readUInt32(_ property: AudioDeviceProperty) -> UInt32? {
    reads += 1
    return values[property]
  }

  func readName(_ device: AudioObjectID) -> String? {
    names[device]
  }

  func observe(_ property: AudioDeviceProperty, changed: @escaping @MainActor @Sendable () -> Void)
    -> (@MainActor () -> Void)?
  {
    guard !failures.contains(property) else { return nil }
    installations[property, default: 0] += 1
    observers[property] = changed
    return { self.observers[property] = nil }
  }

  func emit(_ property: AudioDeviceProperty) {
    observers[property]?()
  }
}
