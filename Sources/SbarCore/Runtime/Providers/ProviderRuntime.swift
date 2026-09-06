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
  private(set) var widgetStates: [ItemType: WidgetState] = [:]
  private(set) var widgetSnapshots: [String: WidgetState] = [:]
  private(set) var frontApplication: FrontApplicationState?
  private(set) var applicationSnapshots: [String: FrontApplicationState] = [:]
  private(set) var itemDates: [String: Date] = [:]

  @ObservationIgnored private var refreshItems: [Item] = []
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var lastRefresh: [String: Date] = [:]

  @ObservationIgnored private let application = FrontApplicationProvider()
  @ObservationIgnored private let battery = BatteryProvider()
  @ObservationIgnored private let volume = VolumeProvider()
  @ObservationIgnored private let network = NetworkProvider()
  @ObservationIgnored private let media = MediaProvider()
  @ObservationIgnored private let spaces = SpacesProvider()
  @ObservationIgnored private var samplingTask: Task<Void, Never>?

  @ObservationIgnored private var commandTasks: [String: Task<Void, Never>] = [:]

  @ObservationIgnored private var pluginItems: [Item] = []
  @ObservationIgnored private var pluginTasks: [String: Task<Void, Never>] = [:]
  @ObservationIgnored private var pluginInputs: [String: PluginMailbox] = [:]
  @ObservationIgnored private var pluginGeneration = UUID()

  @ObservationIgnored private var adapterTask: Task<Void, Never>?
  @ObservationIgnored private var commandItems: [Item] = []
  @ObservationIgnored private var activeTypes: Set<ItemType> = []
  @ObservationIgnored private let metrics = SystemMetricsSampler()

  func configure(_ configuration: Configuration) {
    configureRefresh(configuration.items.active)
    configurePlugins(configuration.items.active.filter { $0.type == .plugin })
    configureCommands(configuration.items.active.filter { $0.enabled && $0.type == .command })

    let requested = Set(configuration.items.active.map(\.type)).subtracting([
      .command, .plugin, .text, .spacer, .divider, .group, .popup,
    ])
    guard requested != activeTypes else { return }

    stopNative()
    activeTypes = requested

    if activeTypes.contains(.frontApplication) {
      application.start { [weak self] in self?.updateFrontApplication($0) }
    }

    if activeTypes.contains(.battery) {
      battery.start { [weak self] in self?.updateWidgetState($0, for: .battery) }
    }

    if activeTypes.contains(.volume) {
      volume.start { [weak self] in self?.updateSharedValues([.volume: $0]) }
    }

    if activeTypes.contains(.network) || activeTypes.contains(.wifi) {
      network.start { [weak self] network, wifi in
        self?.updateWidgetState(wifi, for: .wifi)
        self?.updateSharedValues([.network: network])
      }
    }

    if activeTypes.contains(.media) {
      media.start { [weak self] in self?.updateSharedValues([.media: $0]) }
    }

    if activeTypes.contains(.spaces) {
      spaces.start { [weak self] in self?.updateSharedValues([.spaces: $0]) }
    }

    let adapters = activeTypes.intersection([.aerospace, .yabai])
    if !adapters.isEmpty {
      adapterTask = Task { [weak self] in
        while !Task.isCancelled {
          for adapter in adapters {
            let value = (try? await WorkspaceProvider.query(adapter)) ?? "Workspace unavailable"
            guard !Task.isCancelled else { return }

            self?.updateSharedValues([adapter: value])
          }

          do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
      }
    }

    let sampled = activeTypes.intersection([.cpu, .memory, .disk, .throughput])
    let needsClock = activeTypes.contains(.datetime)
    if !sampled.isEmpty || needsClock {
      samplingTask = Task { [weak self, metrics] in
        var tick = 0

        while !Task.isCancelled {
          if needsClock { self?.currentDate = Date() }
          if !needsClock || tick % 2 == 0, !sampled.isEmpty {
            let snapshot = await metrics.sample(sampled)
            guard !Task.isCancelled else { return }

            self?.updateSharedValues(snapshot)
          }

          tick += 1
          do { try await Task.sleep(for: .seconds(needsClock ? 1 : 2)) } catch { return }
        }
      }
    }
  }

  func presentation(for item: Item) -> WidgetPresentation? {
    let state = item.refresh == nil ? widgetStates[item.type] : widgetSnapshots[item.id]
    return state?.presentation(for: item)
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
      capture(item)
    }

    for input in pluginInputs.values { input.send(PluginInput(event: event, value: value)) }

    for item in commandItems
    where item.refresh?.event == event || item.id == event {
      startCommand(item)
    }
  }

  func stop() {
    refreshTask?.cancel()
    refreshTask = nil
    refreshItems = []

    frontApplication = nil
    sharedValues = [:]
    widgetStates = [:]
    itemValues = [:]
    itemSnapshots = [:]
    widgetSnapshots = [:]
    applicationSnapshots = [:]
    itemDates = [:]
    lastRefresh = [:]

    pluginGeneration = UUID()
    for task in pluginTasks.values { task.cancel() }
    pluginTasks.removeAll()
    pluginInputs.removeAll()
    pluginItems = []

    for task in commandTasks.values { task.cancel() }
    commandTasks.removeAll()
    commandItems = []

    stopNative()
  }

  private func configureRefresh(_ items: [Item]) {
    let requested = items.filter { $0.refresh != nil && $0.type != .command && $0.type != .plugin }
    let same =
      requested.count == refreshItems.count
      && requested.allSatisfy { item in
        refreshItems.contains {
          $0.id == item.id && $0.type == item.type && $0.refresh == item.refresh
        }
      }
    guard !same else {
      refreshItems = requested
      return
    }

    refreshTask?.cancel()
    refreshItems = requested
    itemSnapshots = [:]
    widgetSnapshots = [:]
    applicationSnapshots = [:]
    itemDates = [:]
    lastRefresh = [:]
    for item in requested { capture(item) }

    guard requested.contains(where: { $0.refresh?.mode == .interval }) else { return }

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
    let same =
      items.count == pluginItems.count
      && items.allSatisfy { item in
        pluginItems.contains { $0.id == item.id && $0.plugin == item.plugin }
      }
    guard !same else {
      pluginItems = items
      return
    }

    pluginGeneration = UUID()
    let generation = pluginGeneration

    for task in pluginTasks.values { task.cancel() }
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
            try await PluginRunner.run(configuration: configuration, mailbox: input) {
              [weak self] text in
              Task { @MainActor [weak self] in
                guard self?.pluginGeneration == generation else { return }

                self?.updateItemValue(text, for: item.id)
              }
            }
          } catch {
            guard !Task.isCancelled, self?.pluginGeneration == generation else { return }

            self?.updateItemValue(error.localizedDescription, for: item.id)
          }

          guard configuration.restart ?? true else { return }
          do { try await Task.sleep(for: .seconds(delay)) } catch { return }
          delay = min(30, delay * 2)
        } while !Task.isCancelled
      }
    }
  }

  private func configureCommands(_ items: [Item]) {
    let previous = Dictionary(uniqueKeysWithValues: commandItems.map { ($0.id, $0) })
    let ids = Set(items.map(\.id))

    for id in commandTasks.keys.filter({ !ids.contains($0) }) {
      commandTasks.removeValue(forKey: id)?.cancel()
    }

    commandItems = items
    itemValues = itemValues.filter { key, _ in (items + pluginItems).contains { $0.id == key } }

    for item in items
    where previous[item.id] == nil || previous[item.id]?.command != item.command
      || previous[item.id]?.refresh != item.refresh
    {
      startCommand(item)
    }
  }

  private func startCommand(_ item: Item) {
    guard let command = item.command else { return }

    commandTasks[item.id]?.cancel()
    commandTasks[item.id] = Task { [weak self] in
      repeat {
        do {
          let result = try await ProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", command.script],
            timeout: command.timeout ?? 5
          )
          guard !Task.isCancelled else { return }

          self?.updateItemValue(
            result.exitCode == 0 ? result.output : "Exit \(result.exitCode): \(result.output)",
            for: item.id
          )
        } catch {
          guard !Task.isCancelled else { return }

          self?.updateItemValue(error.localizedDescription, for: item.id)
        }

        let duration = item.refresh?.mode == .interval ? item.refresh?.seconds : nil
        guard let interval = duration else { return }
        do { try await Task.sleep(for: .seconds(interval)) } catch { return }
      } while !Task.isCancelled
    }
  }

  private func stopNative() {
    adapterTask?.cancel()
    adapterTask = nil
    samplingTask?.cancel()
    samplingTask = nil

    application.stop()
    battery.stop()
    volume.stop()
    network.stop()
    media.stop()
    spaces.stop()

    activeTypes = []
  }
}
