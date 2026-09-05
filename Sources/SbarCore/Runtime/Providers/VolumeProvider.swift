import CoreAudio
import Foundation

@MainActor
final class VolumeProvider {
  private var audioListeners:
    [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
  private var update: (@MainActor (String) -> Void)?

  func start(update: @escaping @MainActor (String) -> Void) {
    stop()
    self.update = update
    installAudioListeners()
  }

  func stop() {
    for (object, var address, listener) in audioListeners {
      AudioObjectRemovePropertyListenerBlock(object, &address, .main, listener)
    }
    audioListeners.removeAll()
    update = nil
  }

  private func installAudioListeners() {
    guard update != nil else { return }

    for (object, var address, listener) in audioListeners {
      AudioObjectRemovePropertyListenerBlock(object, &address, .main, listener)
    }
    audioListeners.removeAll()

    var device = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &device
    )

    let changed: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in self?.installAudioListeners() }
    }
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      .main,
      changed
    )
    audioListeners.append((AudioObjectID(kAudioObjectSystemObject), address, changed))

    guard device != 0 else {
      update?("No output")
      return
    }

    for (selector, element) in [
      (kAudioDevicePropertyVolumeScalar, UInt32(0)), (kAudioDevicePropertyVolumeScalar, UInt32(1)),
      (kAudioDevicePropertyVolumeScalar, UInt32(2)), (kAudioDevicePropertyMute, UInt32(0)),
    ] {
      var property = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: element
      )
      let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        Task { @MainActor [weak self] in self?.updateVolume(device) }
      }
      if AudioObjectAddPropertyListenerBlock(device, &property, .main, listener) == noErr {
        audioListeners.append((device, property, listener))
      }
    }

    updateVolume(device)
  }

  private func updateVolume(_ device: AudioDeviceID) {
    var volume: Float32 = 0
    var muted: UInt32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var result = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
    if result != noErr {
      var channels: [Float32] = []
      for element: UInt32 in [1, 2] {
        address.mElement = element
        var channel: Float32 = 0
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &channel) == noErr {
          channels.append(channel)
        }
      }

      if !channels.isEmpty {
        volume = channels.reduce(0, +) / Float32(channels.count)
        result = noErr
      }
    }

    address.mElement = kAudioObjectPropertyElementMain
    address.mSelector = kAudioDevicePropertyMute
    AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)

    update?(
      muted != 0
        ? "Muted"
        : result == noErr
          ? "Volume \(Int((volume.isFinite ? min(1, max(0, volume)) : 0) * 100))%" : "Fixed volume"
    )
  }
}
