import AppKit
import Foundation
import Observation

@MainActor @Observable
final class ProviderRuntime {
  private(set) var sharedValues: [ItemType: String] = [:] {
    didSet {
      for (key, value) in sharedValues where oldValue[key] != value {
        onValueChange?(key.rawValue, value)
      }

      for item in refreshItems
      where item.type != .datetime
        && (item.refresh?.mode == .event || itemSnapshots[item.id] == nil)
      { capture(item) }
    }
  }

  private(set) var itemValues: [String: String] = [:] {
    didSet {
      for (key, value) in itemValues where oldValue[key] != value { onValueChange?(key, value) }
    }
  }

  @ObservationIgnored var onValueChange: ((String, String) -> Void)?

  private(set) var currentDate = Date() {
    didSet {
      for item in refreshItems
      where item.refresh?.mode == .event && item.type == .datetime {
        capture(item)
      }
    }
  }

  private(set) var itemSnapshots: [String: String] = [:]
  private(set) var diskStates: [String: DiskState] = [:]
  private(set) var pluginStates: [String: PluginState] = [:]
  private(set) var commandStates: [String: CommandState] = [:]
  private(set) var widgetStates: [ItemType: WidgetState] = [:]
  private(set) var widgetSnapshots: [String: WidgetState] = [:]
  private(set) var frontApplication: FrontApplicationState?
  private(set) var applicationSnapshots: [String: FrontApplicationState] = [:]
  private(set) var itemDates: [String: Date] = [:]

  @ObservationIgnored private var diskItems: [String: String] = [:]
  @ObservationIgnored private var refreshItems: [Item] = []
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var lastRefresh: [String: Date] = [:]

  @ObservationIgnored private let application = FrontApplicationProvider()
  @ObservationIgnored private let battery = BatteryProvider()
  @ObservationIgnored private let volume = VolumeProvider()
  @ObservationIgnored private let network = NetworkProvider()
  @ObservationIgnored private let mail: MailProvider
  @ObservationIgnored private let vpn: VPNProvider
  @ObservationIgnored private let bluetooth: BluetoothProvider
  @ObservationIgnored private let audioDevice: AudioDeviceProvider
  @ObservationIgnored private let media = MediaProvider()
  @ObservationIgnored private let aerospace: AerospaceProvider
  @ObservationIgnored private var aerospaceCaptures = Set<String>()
  @ObservationIgnored private let spaces = SpacesProvider()
  @ObservationIgnored private var samplingTask: Task<Void, Never>?

  @ObservationIgnored private var commandTasks: [String: Task<Void, Never>] = [:]

  @ObservationIgnored private var pluginItems: [Item] = []
  @ObservationIgnored private var pluginTasks: [String: Task<Void, Never>] = [:]
  @ObservationIgnored private var pluginInputs: [String: PluginMailbox] = [:]
  @ObservationIgnored private var pluginGenerations: [String: UUID] = [:]
  @ObservationIgnored private var pluginHadOutput: [String: Bool] = [:]

  @ObservationIgnored private let yabai: YabaiProvider
  @ObservationIgnored private var yabaiCaptures = Set<String>()
  @ObservationIgnored private var commandItems: [Item] = []
  @ObservationIgnored private var activeTypes: Set<ItemType> = []
  @ObservationIgnored private let metrics = SystemMetricsSampler()

  init(
    aerospace: AerospaceProvider = AerospaceProvider(),
    yabai: YabaiProvider = YabaiProvider(),
    mail: MailProvider = MailProvider(),
    vpn: VPNProvider = VPNProvider(),
    bluetooth: BluetoothProvider = BluetoothProvider(),
    audioDevice: AudioDeviceProvider = AudioDeviceProvider()
  ) {
    self.aerospace = aerospace
    self.yabai = yabai
    self.mail = mail
    self.vpn = vpn
    self.bluetooth = bluetooth
    self.audioDevice = audioDevice
  }

  func configure(_ configuration: Configuration) {
    let disks = Dictionary(
      uniqueKeysWithValues: configuration.items.active.filter { $0.type == .disk }.map {
        ($0.id, ($0.disk ?? DiskConfiguration()).resolvedPath)
      }
    )
    diskItems = disks
    diskStates = diskStates.filter { disks.values.contains($0.key) }
    configureRefresh(configuration.items.active)
    configurePlugins(configuration.items.active.filter { $0.type == .plugin })
    configureCommands(configuration.items.active.filter { $0.enabled && $0.type == .command })

    let requested = Set(configuration.items.active.map(\.type)).subtracting([
      .command, .plugin, .text, .spacer, .divider, .group, .popup,
    ])
    guard requested != activeTypes else { return }

    let added = requested.subtracting(activeTypes)
    let removed = activeTypes.subtracting(requested)
    stopNative(removed)
    activeTypes = requested

    if added.contains(.frontApplication) {
      application.start { [weak self] in self?.updateFrontApplication($0) }
    }

    if added.contains(.battery) {
      battery.start { [weak self] in self?.updateWidgetState($0, for: .battery) }
    }

    if added.contains(.volume) {
      volume.start { [weak self] in self?.updateWidgetState($0, for: .volume) }
    }

    if added.contains(.bluetooth) {
      bluetooth.start { [weak self] in self?.updateWidgetState(.bluetooth($0), for: .bluetooth) }
    }

    if added.contains(.audioDevice) {
      audioDevice.start { [weak self] in
        self?.updateWidgetState(.audioDevice($0), for: .audioDevice)
      }
    }

    if added.contains(.mail) {
      mail.start { [weak self] in self?.updateWidgetState(.mail($0), for: .mail) }
    }

    if added.contains(.vpn) {
      vpn.start { [weak self] in self?.updateWidgetState(.vpn($0), for: .vpn) }
    }

    if added.contains(.network) {
      network.start { [weak self] network in
        self?.updateWidgetState(network, for: .network)
      }
    }

    if added.contains(.media) {
      media.start { [weak self] in self?.updateWidgetState(.media($0), for: .media) }
    }

    if added.contains(.spaces) {
      spaces.start { [weak self] in self?.updateWidgetState(.spaces($0), for: .spaces) }
    }

    if added.contains(.aerospace) {
      aerospace.start { [weak self] state in
        guard let self else { return }
        self.updateWidgetState(.aerospace(state), for: .aerospace)
        for item in self.refreshItems where self.aerospaceCaptures.contains(item.id) {
          self.capture(item)
        }
        self.aerospaceCaptures.removeAll()
      }
    }

    if added.contains(.yabai) {
      yabai.start { [weak self] state in
        guard let self else { return }
        self.updateWidgetState(.yabai(state), for: .yabai)
        for item in self.refreshItems where self.yabaiCaptures.contains(item.id) {
          self.capture(item)
        }
        self.yabaiCaptures.removeAll()
      }
    }

    let samplingTypes: Set<ItemType> = [.cpu, .memory, .disk, .throughput, .datetime]
    guard !added.union(removed).isDisjoint(with: samplingTypes) else { return }
    samplingTask?.cancel()
    samplingTask = nil

    let sampled = activeTypes.intersection([.cpu, .memory, .disk, .throughput])
    let needsClock = activeTypes.contains(.datetime)
    if added.contains(.throughput) {
      updateWidgetState(.throughput(ThroughputState()), for: .throughput)
    }
    if added.contains(.memory) { updateWidgetState(.memory(MemoryState()), for: .memory) }
    if added.contains(.cpu) { updateWidgetState(.cpu(CPUState()), for: .cpu) }
    if !sampled.isEmpty || needsClock {
      samplingTask = Task { [weak self, metrics] in
        await metrics.resetBaselines(for: added)
        var tick = 0

        while !Task.isCancelled {
          if needsClock { self?.currentDate = Date() }
          if !needsClock || tick % 2 == 0, !sampled.isEmpty {
            let paths = Set(self?.diskItems.values.map { $0 } ?? [])
            let snapshot = await metrics.sample(sampled, diskPaths: paths)
            guard !Task.isCancelled else { return }

            if let cpu = snapshot.cpu { self?.updateWidgetState(.cpu(cpu), for: .cpu) }
            if let memory = snapshot.memory {
              self?.updateWidgetState(.memory(memory), for: .memory)
            }
            self?.updateDiskStates(snapshot.disks)
            if let throughput = snapshot.throughput {
              self?.updateWidgetState(.throughput(throughput), for: .throughput)
            }
          }

          tick += 1
          do { try await Task.sleep(for: .seconds(needsClock ? 1 : 2)) } catch { return }
        }
      }
    }
  }

  func presentation(for item: Item, displayUUID: String? = nil) -> WidgetPresentation? {
    var presentation: WidgetPresentation?
    var values: [String: String] = [:]
    if item.type == .plugin {
      let state = pluginStates[item.id] ?? PluginState()
      presentation = state.presentation(for: item)
      values = ["status": String(describing: state.status), "error": state.error ?? ""]
    } else if item.type == .command {
      let state = commandStates[item.id] ?? CommandState()
      presentation = state.presentation(for: item)
      values = ["status": String(describing: state.status), "error": state.error ?? ""]
    } else {
      let state: WidgetState?
      if item.type == .disk {
        state =
          item.refresh == nil
          ? .disk(diskStates[(item.disk ?? DiskConfiguration()).resolvedPath] ?? DiskState())
          : widgetSnapshots[item.id] ?? .disk(DiskState())
      } else {
        state = item.refresh == nil ? widgetStates[item.type] : widgetSnapshots[item.id]
      }
      presentation = state?.presentation(for: item, displayUUID: displayUUID)
      if item.text != nil { values = state?.textValues(for: item) ?? [:] }
    }
    guard let source = item.text else { return presentation }
    let fallback: String
    switch item.type {
    case .datetime:
      fallback = DateTimeFormatter.string(
        itemDates[item.id] ?? currentDate,
        format: item.format,
        dateStyle: item.dateStyle,
        timeStyle: item.timeStyle
      )
    case .frontApplication:
      let name = itemSnapshots[item.id] ?? sharedValues[.frontApplication] ?? ""
      values["name"] = name
      fallback = item.label ?? name
    case .text: fallback = item.label ?? ""
    case .group, .popup: fallback = item.label ?? item.id
    default: fallback = itemSnapshots[item.id] ?? sharedValues[item.type] ?? "—"
    }
    var resolved =
      presentation
      ?? WidgetPresentation(text: fallback, symbol: item.symbol, accessibilityLabel: fallback)
    values["value"] = resolved.text
    values["id"] = item.id
    guard let template = try? TextTemplate(source, fields: TextTemplate.fields(for: item.type))
    else {
      return resolved
    }
    resolved.text = template.render(values)
    if presentation == nil { resolved.accessibilityLabel = resolved.text }
    resolved.segments = []
    return resolved
  }

  func isVisible(_ item: Item, displayUUID: String? = nil) -> Bool {
    item.enabled && presentation(for: item, displayUUID: displayUUID)?.hidden != true
  }

  func applicationIcon(for item: Item) -> NSImage? {
    guard item.type == .frontApplication, item.frontApplication?.showIcon == true else {
      return nil
    }
    return (item.refresh == nil ? frontApplication : applicationSnapshots[item.id])?.icon
  }

  func updateFrontApplication(_ state: FrontApplicationState) {
    frontApplication = state
    updateSharedValues([.frontApplication: state.name])
    for item in refreshItems
    where item.type == .frontApplication
      && (item.refresh?.mode == .event || applicationSnapshots[item.id] == nil)
    {
      capture(item)
    }
  }

  func updateWidgetState(_ state: WidgetState, for type: ItemType) {
    guard widgetStates[type] != state else { return }
    widgetStates[type] = state
    updateSharedValues([type: state.text])
    for item in refreshItems
    where item.type == type
      && (item.refresh?.mode == .event || widgetSnapshots[item.id] == nil)
    {
      capture(item)
    }
  }

  func updateDiskStates(_ states: [String: DiskState]) {
    let previous = diskStates
    diskStates = states.filter { diskItems.values.contains($0.key) }
    for (id, path) in diskItems {
      let state = diskStates[path] ?? DiskState()
      if previous[path] != state { onValueChange?(id, state.text) }
    }
    for item in refreshItems
    where item.type == .disk
      && (item.refresh?.mode == .event || widgetSnapshots[item.id] == nil)
    {
      capture(item)
    }
  }

  func updateSharedValues(_ values: [ItemType: String]) {
    guard values.contains(where: { sharedValues[$0.key] != $0.value }) else { return }

    sharedValues.merge(values) { _, new in new }
  }

  func updateItemValue(_ value: String, for id: String) {
    guard itemValues[id] != value else { return }

    itemValues[id] = value
  }

  func trigger(_ event: String, value: JSONValue? = nil) {
    for item in refreshItems where item.id == event || item.refresh?.event == event {
      if item.type == .aerospace {
        aerospaceCaptures.insert(item.id)
        aerospace.requestRefresh()
      } else if item.type == .yabai {
        yabaiCaptures.insert(item.id)
        yabai.requestRefresh()
      } else {
        capture(item)
      }
    }

    for input in pluginInputs.values { input.send(PluginInput(event: event, value: value)) }

    for item in commandItems
    where item.refresh?.event == event || item.id == event {
      startCommand(item, coalesce: true)
    }
  }

  func stop() {
    refreshTask?.cancel()
    refreshTask = nil
    refreshItems = []

    frontApplication = nil
    sharedValues = [:]
    diskStates = [:]
    diskItems = [:]
    widgetStates = [:]
    itemValues = [:]
    itemSnapshots = [:]
    widgetSnapshots = [:]
    applicationSnapshots = [:]
    itemDates = [:]
    lastRefresh = [:]

    pluginGenerations = [:]
    pluginStates = [:]
    pluginHadOutput = [:]
    for task in pluginTasks.values { task.cancel() }
    pluginTasks.removeAll()
    pluginInputs.removeAll()
    pluginItems = []

    for task in commandTasks.values { task.cancel() }
    commandTasks.removeAll()
    commandStates = [:]
    commandItems = []

    samplingTask?.cancel()
    samplingTask = nil
    stopNative(activeTypes)
    activeTypes = []
  }

  private func configureRefresh(_ items: [Item]) {
    let requested = items.filter { $0.refresh != nil && $0.type != .command && $0.type != .plugin }
    let previous = Dictionary(uniqueKeysWithValues: refreshItems.map { ($0.id, $0) })
    let unchanged = Set(
      requested.filter { item in
        guard let old = previous[item.id] else { return false }
        return old.type == item.type && old.refresh == item.refresh
          && old.disk?.path == item.disk?.path
      }.map(\.id)
    )
    if unchanged.count == requested.count && requested.count == refreshItems.count {
      refreshItems = requested
      return
    }

    refreshItems = requested
    itemSnapshots = itemSnapshots.filter { unchanged.contains($0.key) }
    widgetSnapshots = widgetSnapshots.filter { unchanged.contains($0.key) }
    applicationSnapshots = applicationSnapshots.filter { unchanged.contains($0.key) }
    itemDates = itemDates.filter { unchanged.contains($0.key) }
    lastRefresh = lastRefresh.filter { unchanged.contains($0.key) }
    aerospaceCaptures.formIntersection(unchanged)
    yabaiCaptures.formIntersection(unchanged)
    for item in requested where !unchanged.contains(item.id) { capture(item) }

    guard requested.contains(where: { $0.refresh?.mode == .interval }) else {
      refreshTask?.cancel()
      refreshTask = nil
      return
    }
    guard refreshTask == nil else { return }

    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }

        for item in self.refreshItems {
          let previous = self.lastRefresh[item.id]
          if item.refresh?.mode == .interval
            && (previous == nil
              || Date().timeIntervalSince(previous ?? .distantPast) >= (item.refresh?.seconds ?? 1))
          {
            self.capture(item)
          }
        }

        do { try await Task.sleep(for: .seconds(1)) } catch { return }
      }
    }
  }

  private func capture(_ item: Item) {
    if item.type == .disk {
      let state = diskStates[(item.disk ?? DiskConfiguration()).resolvedPath] ?? DiskState()
      widgetSnapshots[item.id] = .disk(state)
      itemSnapshots[item.id] = state.text
      lastRefresh[item.id] = Date()
      return
    }
    if item.type == .frontApplication, let frontApplication {
      applicationSnapshots[item.id] = frontApplication
    }
    if let state = widgetStates[item.type] { widgetSnapshots[item.id] = state }
    if let value = sharedValues[item.type] {
      if itemSnapshots[item.id] != value { itemSnapshots[item.id] = value }
      lastRefresh[item.id] = Date()
    }

    if item.type == .datetime {
      itemDates[item.id] = Date()
      lastRefresh[item.id] = Date()
    }
  }

  private func configurePlugins(_ items: [Item]) {
    let previous = Dictionary(uniqueKeysWithValues: pluginItems.map { ($0.id, $0) })
    let ids = Set(items.map(\.id))
    for id in pluginTasks.keys.filter({ !ids.contains($0) }) {
      pluginGenerations[id] = nil
      pluginInputs[id] = nil
      pluginTasks.removeValue(forKey: id)?.cancel()
    }
    pluginItems = items
    pluginStates = pluginStates.filter { ids.contains($0.key) }
    pluginHadOutput = pluginHadOutput.filter { ids.contains($0.key) }
    for item in items where item.plugin?.sameExecution(as: previous[item.id]?.plugin) != true {
      pluginGenerations[item.id] = nil
      pluginInputs[item.id] = nil
      pluginTasks.removeValue(forKey: item.id)?.cancel()
      pluginStates[item.id] = nil
      itemValues[item.id] = nil
      startPlugin(item)
    }
  }

  private func publishPlugin(_ state: PluginState, item: Item) {
    pluginStates[item.id] = state
    let current = pluginItems.first { $0.id == item.id } ?? item
    let retaining = state.status != .failure || current.plugin?.onError == .keepLast
    let text =
      retaining ? state.lastSuccess?.text ?? state.error ?? "…" : state.error ?? "Plugin failed"
    updateItemValue(text, for: item.id)
  }

  private func startPlugin(_ item: Item) {
    guard var configuration = item.plugin else { return }
    configuration.executable = ActionRunner.expand(configuration.executable)
    pluginTasks[item.id] = Task { [weak self, configuration] in
      var delay = 1.0
      repeat {
        guard !Task.isCancelled else { return }
        let generation = UUID()
        let input = PluginMailbox()
        input.send(PluginInput(event: "start", value: nil))
        self?.pluginHadOutput[item.id] = false
        self?.pluginGenerations[item.id] = generation
        self?.pluginInputs[item.id] = input
        var state = self?.pluginStates[item.id] ?? PluginState()
        state.status = .running
        state.error = nil
        self?.publishPlugin(state, item: item)
        let started = ContinuousClock.now
        do {
          try await PluginRunner.run(configuration: configuration, mailbox: input) {
            [weak self] value in
            await self?.receivePlugin(value, item: item, generation: generation)
          }
        } catch {
          guard !Task.isCancelled, self?.pluginGenerations[item.id] == generation else { return }
          var failed = self?.pluginStates[item.id] ?? PluginState()
          failed.status = .failure
          failed.error = error.localizedDescription
          self?.publishPlugin(failed, item: item)
        }
        guard !Task.isCancelled, self?.pluginGenerations[item.id] == generation else { return }
        let receivedOutput = self?.pluginHadOutput[item.id] == true
        self?.pluginGenerations[item.id] = nil
        self?.pluginInputs[item.id] = nil
        guard configuration.restart ?? true else { return }
        delay = PluginState.restartDelay(
          delay,
          uptime: started.duration(to: .now),
          receivedOutput: receivedOutput
        )
        do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        delay = min(30, delay * 2)
      } while !Task.isCancelled
    }
  }

  private func receivePlugin(_ value: PluginOutput, item: Item, generation: UUID) {
    guard pluginGenerations[item.id] == generation else { return }
    pluginHadOutput[item.id] = true
    publishPlugin(PluginState(status: .success, lastSuccess: value), item: item)
  }

  private func configureCommands(_ items: [Item]) {
    let previous = Dictionary(uniqueKeysWithValues: commandItems.map { ($0.id, $0) })
    let ids = Set(items.map(\.id))

    for id in commandTasks.keys.filter({ !ids.contains($0) }) {
      commandTasks.removeValue(forKey: id)?.cancel()
    }

    commandItems = items
    commandStates = commandStates.filter { ids.contains($0.key) }
    itemValues = itemValues.filter { key, _ in (items + pluginItems).contains { $0.id == key } }

    for item in items
    where previous[item.id] == nil
      || item.command?.sameExecution(as: previous[item.id]?.command) != true
      || previous[item.id]?.refresh != item.refresh
    {
      commandStates[item.id] = nil
      itemValues[item.id] = nil
      startCommand(item)
    }
  }

  private func publishCommand(_ state: CommandState, item: Item) {
    commandStates[item.id] = state
    let current = commandItems.first { $0.id == item.id } ?? item
    // Keep raw text so later cosmetic changes can adjust truncation and visibility.
    let retaining = state.status != .failure || current.command?.onError == .keepLast
    let text =
      retaining ? state.lastSuccess?.text ?? state.error ?? "…" : state.error ?? "Command failed"
    updateItemValue(text, for: item.id)
  }

  private func startCommand(_ item: Item, coalesce: Bool = false) {
    guard let command = item.command else { return }
    commandTasks[item.id]?.cancel()
    commandTasks[item.id] = Task { [weak self] in
      if coalesce {
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
      }
      repeat {
        guard !Task.isCancelled else { return }
        var state = self?.commandStates[item.id] ?? CommandState()
        state.status = .running
        state.error = nil
        self?.publishCommand(state, item: item)
        do {
          let result = try await ProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", command.script],
            timeout: command.timeout ?? 5,
            mergeStandardError: command.format != .json && command.output != .stdout
          )
          guard !Task.isCancelled else { return }
          if result.exitCode == 0 {
            state.lastSuccess = try CommandState.decode(result.output, configuration: command)
            state.status = .success
          } else {
            state.status = .failure
            state.error = "Exit \(result.exitCode): \(result.output)"
          }
        } catch {
          guard !Task.isCancelled else { return }
          state.status = .failure
          state.error = error is DecodingError ? "Invalid command JSON" : error.localizedDescription
        }
        guard !Task.isCancelled else { return }
        self?.publishCommand(state, item: item)
        let duration = item.refresh?.mode == .interval ? item.refresh?.seconds : nil
        guard let interval = duration else { return }
        do { try await Task.sleep(for: .seconds(interval)) } catch { return }
      } while !Task.isCancelled
    }
  }

  private func stopNative(_ types: Set<ItemType>) {
    if types.contains(.frontApplication) { application.stop() }
    if types.contains(.battery) { battery.stop() }
    if types.contains(.volume) { volume.stop() }
    if types.contains(.network) { network.stop() }
    if types.contains(.mail) { mail.stop() }
    if types.contains(.vpn) { vpn.stop() }
    if types.contains(.bluetooth) { bluetooth.stop() }
    if types.contains(.audioDevice) { audioDevice.stop() }
    if types.contains(.media) { media.stop() }
    if types.contains(.spaces) { spaces.stop() }
    if types.contains(.yabai) {
      yabai.stop()
      yabaiCaptures.removeAll()
    }
    if types.contains(.aerospace) {
      aerospace.stop()
      aerospaceCaptures.removeAll()
    }
  }
}
