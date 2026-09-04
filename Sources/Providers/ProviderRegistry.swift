import AppKit
import ControlProtocol
import CoreAudio
import IOKit.ps
import Network
import Observation

@MainActor @Observable
final class ProviderRegistry {
    private(set) var values: [ItemType: String] = [:] {
        didSet { for (key, value) in values where oldValue[key] != value { onValueChange?(key.rawValue, value) } }
    }
    private(set) var itemValues: [String: String] = [:] {
        didSet { for (key, value) in itemValues where oldValue[key] != value { onValueChange?(key, value) } }
    }
    @ObservationIgnored var onValueChange: ((String, String) -> Void)?
    private(set) var date = Date()

    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var powerSource: CFRunLoopSource?
    @ObservationIgnored private var audioListeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    @ObservationIgnored private var commandTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var pluginItems: [ItemConfiguration] = []
    @ObservationIgnored private var pluginTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var pluginInputs: [String: PluginMailbox] = [:]
    @ObservationIgnored private var pluginGeneration = UUID()
    @ObservationIgnored private var adapterTask: Task<Void, Never>?
    @ObservationIgnored private var commandItems: [ItemConfiguration] = []
    @ObservationIgnored private var types: Set<ItemType> = []
    @ObservationIgnored private let metrics = SystemMetrics()

    func configure(_ configuration: BarConfiguration) {
        configurePlugins(configuration.items.active.filter { $0.type == .plugin })
        configureCommands(configuration.items.active.filter { $0.enabled && $0.type == .command })
        let requested = Set(configuration.items.active.filter(\.enabled).map(\.type))
        guard requested != types else { return }
        stopNative()
        types = requested
        if types.contains(.frontApplication) {
            updateApplication()
            observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.didActivateApplicationNotification) { [weak self] _ in self?.updateApplication() }
        }
        if types.contains(.battery) {
            updateBattery()
            powerSource = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let registry = Unmanaged<ProviderRegistry>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { registry.updateBattery() }
            }, Unmanaged.passUnretained(self).toOpaque()).takeRetainedValue()
            CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes)
        }
        if types.contains(.volume) { installAudioListeners() }
        if types.contains(.network) || types.contains(.wifi) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                let connected = path.status == .satisfied
                let wifi = path.usesInterfaceType(.wifi)
                let network = connected ? (wifi ? "Wi-Fi" : "Connected") : "Offline"
                Task { @MainActor [weak self] in
                    self?.values[.network] = network
                    self?.values[.wifi] = wifi && connected ? "Wi-Fi connected" : "Wi-Fi disconnected"
                }
            }
            monitor.start(queue: DispatchQueue(label: "starkbar.network"))
            self.monitor = monitor
        }
        if types.contains(.media) {
            values[.media] = "Waiting for playback"
            for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
                observe(DistributedNotificationCenter.default(), name: Notification.Name(name)) { [weak self] info in
                    let state = info["Player State"] ?? ""
                    let title = info["Name"] ?? ""
                    let artist = info["Artist"] ?? ""
                    self?.values[.media] = state == "Playing" ? [title, artist].filter { !$0.isEmpty }.joined(separator: " — ") : "Paused"
                }
            }
        }
        let adapters = types.intersection([.aerospace, .yabai])
        if !adapters.isEmpty {
            adapterTask = Task { [weak self] in
                while !Task.isCancelled {
                    for adapter in adapters {
                        let value = (try? await WorkspaceAdapter.query(adapter)) ?? "Workspace unavailable"
                        guard !Task.isCancelled else { return }
                        self?.values[adapter] = value
                    }
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                }
            }
        }
        let sampled = types.intersection([.cpu, .memory, .disk, .throughput])
        let needsClock = !types.isDisjoint(with: [.clock, .date])
        if !sampled.isEmpty || needsClock {
            task = Task { [weak self, metrics] in
                var tick = 0
                while !Task.isCancelled {
                    if needsClock { self?.date = Date() }
                    if tick % 2 == 0, !sampled.isEmpty {
                        let snapshot = await metrics.sample(sampled)
                        guard !Task.isCancelled else { return }
                        self?.values.merge(snapshot) { _, new in new }
                    }
                    tick += 1
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
            }
        }
    }

    func trigger(_ event: String, value: JSONValue? = nil) {
        for input in pluginInputs.values { input.send(PluginInput(event: event, value: value)) }
        for item in commandItems where item.command?.event == event { startCommand(item) }
    }

    func stop() {
        pluginGeneration = UUID()
        pluginTasks.values.forEach { $0.cancel() }
        pluginTasks.removeAll()
        pluginInputs.removeAll()
        pluginItems = []
        commandTasks.values.forEach { $0.cancel() }
        commandTasks.removeAll()
        commandItems = []
        stopNative()
    }

    private func configurePlugins(_ items: [ItemConfiguration]) {
        guard items != pluginItems else { return }
        pluginGeneration = UUID()
        let generation = pluginGeneration
        pluginTasks.values.forEach { $0.cancel() }
        pluginTasks.removeAll()
        pluginInputs.removeAll()
        pluginItems = items
        for item in items {
            guard var configuration = item.plugin else { continue }
            configuration.executable = ActionRunner.expand(configuration.executable)
            let input = PluginMailbox()
            pluginInputs[item.id] = input
            pluginTasks[item.id] = Task { [weak self, configuration] in
                var delay = 1.0
                repeat {
                    input.send(PluginInput(event: "start", value: nil))
                    do {
                        try await PluginProcess.run(configuration: configuration, mailbox: input) { [weak self] text in
                            Task { @MainActor [weak self] in
                                guard self?.pluginGeneration == generation else { return }
                                self?.itemValues[item.id] = text
                            }
                        }
                    } catch {
                        guard !Task.isCancelled, self?.pluginGeneration == generation else { return }
                        self?.itemValues[item.id] = error.localizedDescription
                    }
                    guard configuration.restart ?? true else { return }
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                    delay = min(30, delay * 2)
                } while !Task.isCancelled
            }
        }
    }

    private func configureCommands(_ items: [ItemConfiguration]) {
        guard items != commandItems else { return }
        commandTasks.values.forEach { $0.cancel() }
        commandTasks.removeAll()
        commandItems = items
        itemValues = itemValues.filter { key, _ in (items + pluginItems).contains { $0.id == key } }
        for item in items { startCommand(item) }
    }

    private func startCommand(_ item: ItemConfiguration) {
        guard let command = item.command else { return }
        commandTasks[item.id]?.cancel()
        commandTasks[item.id] = Task { [weak self] in
            repeat {
                do {
                    let result = try await CommandRunner.run(executable: "/bin/sh", arguments: ["-c", command.script], timeout: command.timeout ?? 5)
                    guard !Task.isCancelled else { return }
                    self?.itemValues[item.id] = result.status == 0 ? result.output : "Exit \(result.status): \(result.output)"
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.itemValues[item.id] = error.localizedDescription
                }
                guard let interval = command.interval else { return }
                do { try await Task.sleep(for: .seconds(interval)) } catch { return }
            } while !Task.isCancelled
        }
    }

    private func stopNative() {
        adapterTask?.cancel()
        adapterTask = nil
        task?.cancel()
        task = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        monitor?.cancel()
        monitor = nil
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        powerSource = nil
        for (object, var address, listener) in audioListeners {
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, listener)
        }
        audioListeners.removeAll()
        types = []
    }

    private func observe(_ center: NotificationCenter, name: Notification.Name, handler: @escaping @MainActor ([String: String]) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
            let info = notification.userInfo?.reduce(into: [String: String]()) { result, entry in
                if let key = entry.key as? String, let value = entry.value as? String { result[key] = value }
            } ?? [:]
            MainActor.assumeIsolated { handler(info) }
        }
        observers.append((center, token))
    }

    private func updateApplication() {
        values[.frontApplication] = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
    }

    private func updateBattery() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            let charging = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            values[.battery] = "\(charging ? "⚡ " : "")\(capacity * 100 / maximum)%"
            return
        }
        values[.battery] = "AC power"
    }

    private func installAudioListeners() {
        guard types.contains(.volume) else { return }
        for (object, var address, listener) in audioListeners {
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, listener)
        }
        audioListeners.removeAll()
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        let changed: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.installAudioListeners() }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, changed)
        audioListeners.append((AudioObjectID(kAudioObjectSystemObject), address, changed))
        guard device != 0 else { values[.volume] = "No output"; return }
        for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
            var property = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
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
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let result = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        address.mSelector = kAudioDevicePropertyMute
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        values[.volume] = muted != 0 ? "Muted" : result == noErr ? "Volume \(Int(volume * 100))%" : "Fixed volume"
    }
}
