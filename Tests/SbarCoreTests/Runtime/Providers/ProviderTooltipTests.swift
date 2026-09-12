import Foundation
import Testing

@testable import SbarCore

@Suite("Provider tooltips")
@MainActor
struct ProviderTooltipTests {
  @Test("defaults, opt-outs, and common tokens work on ordinary items")
  func defaults() {
    let runtime = ProviderRuntime()
    var item = Item(id: "greeting", type: .text, label: "Hello")

    #expect(runtime.tooltip(for: item) == "Hello")

    item.label = nil
    #expect(runtime.tooltip(for: item) == "greeting")

    for value in ["", " \n\t"] {
      item.tooltip = value
      #expect(runtime.tooltip(for: item) == nil)
    }

    item.label = "Hello"
    item.tooltip = "{id}: {label} / {text} / {summary}"
    #expect(runtime.tooltip(for: item) == "greeting: Hello / Hello / Hello")

    item.tooltip = "Literal text"
    #expect(runtime.tooltip(for: item) == "Literal text")
  }

  @Test("hidden readings stay available and CPU smoothing uses the item's snapshot")
  func snapshots() throws {
    let item = Item(
      id: "cpu",
      type: .cpu,
      tooltip: "CPU {percentage}%: {status}",
      cpu: CPUConfiguration(showLabel: false, showPercentage: false, smoothingSamples: 2),
      refresh: RefreshPolicy(mode: .manual)
    )

    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }

    runtime.updateWidgetState(.cpu(CPUState(samples: [10, 50])), for: .cpu)
    runtime.trigger(item.id)

    #expect(runtime.presentation(for: item)?.text == "")
    #expect(runtime.tooltip(for: item) == "CPU 30%: available")

    runtime.updateWidgetState(.cpu(CPUState(samples: [90])), for: .cpu)
    #expect(runtime.tooltip(for: item) == "CPU 30%: available")

    runtime.trigger(item.id)
    #expect(runtime.tooltip(for: item) == "CPU 90%: available")

    runtime.updateWidgetState(.cpu(CPUState()), for: .cpu)
    runtime.trigger(item.id)

    #expect(runtime.tooltip(for: item) == "CPU —%: unavailable")
  }

  @Test("battery, memory, and volume expose readings hidden from the label")
  func readings() {
    let runtime = ProviderRuntime()
    let battery = Item(
      id: "battery",
      type: .battery,
      tooltip: "{percentage}%: {status}",
      battery: BatteryConfiguration(showPercentage: false)
    )

    runtime.updateWidgetState(
      .battery(percentage: 42, charging: true, pluggedIn: true),
      for: .battery
    )

    #expect(runtime.tooltip(for: battery) == "42%: charging")

    let memory = Item(
      id: "memory",
      type: .memory,
      tooltip: "{used} / {total}: {percentage}%",
      memory: MemoryConfiguration(showLabel: false, showValue: false)
    )

    runtime.updateWidgetState(
      .memory(MemoryState(usedBytes: 0, totalBytes: 8_589_934_592)),
      for: .memory
    )

    let total = ByteCountFormatter.string(fromByteCount: 8_589_934_592, countStyle: .memory)
    let used = ByteCountFormatter.string(fromByteCount: 0, countStyle: .memory)

    #expect(runtime.tooltip(for: memory) == "\(used) / \(total): 0%")

    runtime.updateWidgetState(.memory(MemoryState(usedBytes: 10, totalBytes: 0)), for: .memory)
    #expect(runtime.tooltip(for: memory) == "— / —: —%")

    let volume = Item(id: "volume", type: .volume, tooltip: "{percentage}%: {status}")
    runtime.updateWidgetState(.volume(percentage: 30, muted: true, available: true), for: .volume)

    #expect(runtime.tooltip(for: volume) == "30%: muted")

    runtime.updateWidgetState(
      .volume(percentage: nil, muted: false, available: false),
      for: .volume
    )

    #expect(runtime.tooltip(for: volume) == "—%: unavailable")
  }

  @Test("disk tokens respect path selection and manual refresh")
  func disk() {
    let item = Item(
      id: "disk",
      type: .disk,
      tooltip: "{path}: {free} free, {used} used / {total}, {percentage}%",
      disk: DiskConfiguration(path: "/", showValue: false),
      refresh: RefreshPolicy(mode: .manual)
    )

    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }

    let state = DiskState(freeBytes: 500_000_000, totalBytes: 1_000_000_000)
    runtime.updateDiskStates(["/": state, "/other": DiskState(freeBytes: 0, totalBytes: 10)])
    runtime.trigger(item.id)

    let expected =
      "/: \(state.value(format: .free)) free, \(state.value(format: .used)) used / \(state.value(format: .total)), 50%"

    #expect(runtime.tooltip(for: item) == expected)

    runtime.updateDiskStates(["/": DiskState()])
    #expect(runtime.tooltip(for: item) == expected)

    runtime.trigger(item.id)
    #expect(runtime.tooltip(for: item) == "/: — free, — used / —, —%")
  }

  @Test("throughput tokens keep both directions, selected interfaces, smoothing, and units")
  func throughput() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "throughput",
      type: .throughput,
      tooltip: "{download}\n{upload}",
      throughput: ThroughputConfiguration(
        interfaces: ["en0"],
        unit: .bits,
        showUpload: false,
        showValue: false,
        showUnits: false,
        smoothingSamples: 2
      )
    )

    runtime.updateWidgetState(
      .throughput(
        ThroughputState(histories: [
          "en0": [.init(download: 1000, upload: 500), .init(download: 2000, upload: 1000)],
          "en1": [.init(download: 1_000_000, upload: 1_000_000)],
        ])
      ),
      for: .throughput
    )

    #expect(runtime.tooltip(for: item) == "12 kbit/s\n6 kbit/s")
  }

  @Test("media tokens follow the selected player and preserve metadata literally")
  func media() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "media",
      type: .media,
      tooltip: "{source}: {title}\n{artist} ({status})",
      media: MediaConfiguration(source: .music, showTitle: false, showArtist: false)
    )

    runtime.updateWidgetState(
      .media(
        MediaState(players: [
          .music: MediaPlayerState(
            source: .music,
            status: .paused,
            title: "{artist}",
            artist: "Björk",
            sequence: 1
          ),
          .spotify: MediaPlayerState(
            source: .spotify,
            status: .playing,
            title: "Other",
            sequence: 2
          ),
        ])
      ),
      for: .media
    )

    #expect(runtime.tooltip(for: item) == "Music: {artist}\nBjörk (paused)")
  }

  @Test("connection and device tokens respect selection, names, and status labels")
  func connections() {
    let runtime = ProviderRuntime()
    let vpn = Item(
      id: "vpn",
      type: .vpn,
      tooltip: "{names}: {status} ({count})",
      vpn: VPNConfiguration(labels: ["connected": "Online"], showName: false)
    )

    runtime.updateWidgetState(
      .vpn(
        VPNState(
          services: [
            .init(id: "2", name: " Zeta ", status: .connected),
            .init(id: "1", name: "Alpha", status: .connecting),
            .init(id: "3", name: "Hidden", status: .disconnected),
          ],
          available: true
        )
      ),
      for: .vpn
    )

    #expect(runtime.tooltip(for: vpn) == "Zeta, Alpha: Online (2)")

    let bluetooth = Item(id: "bluetooth", type: .bluetooth, tooltip: "{names}: {count} {status}")

    runtime.updateWidgetState(
      .bluetooth(
        BluetoothState(
          status: .connected,
          devices: [
            .init(id: "2", name: "Mouse"), .init(id: "1", name: "Keyboard"),
          ]
        )
      ),
      for: .bluetooth
    )

    #expect(runtime.tooltip(for: bluetooth) == "Keyboard, Mouse: 2 connected")

    let audio = Item(
      id: "audio",
      type: .audioDevice,
      tooltip: "{device}: {name}, {status}",
      audioDevice: AudioDeviceConfiguration(device: .input, labels: ["available": "Mic"])
    )

    runtime.updateWidgetState(
      .audioDevice(
        AudioDeviceState(
          output: .init(status: .available, name: "Speakers"),
          input: .init(status: .available, name: "Studio Microphone")
        )
      ),
      for: .audioDevice
    )

    #expect(runtime.tooltip(for: audio) == "input: Studio Microphone, available")

    let network = Item(
      id: "network",
      type: .network,
      tooltip: "{interface}: {status}",
      network: NetworkConfiguration(interface: .wifi)
    )

    runtime.updateWidgetState(.network(.ethernet), for: .network)

    #expect(runtime.tooltip(for: network) == "wifi: disconnected")
  }

  @Test("workspace tokens use display scope, fullscreen filtering, and label mappings")
  func workspaces() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "spaces",
      type: .spaces,
      tooltip: "{workspace}: {index}/{count}\n{workspaces}",
      spaces: SpacesConfiguration(
        scope: .display,
        labels: ["2": "Code"],
        includeFullscreen: false,
        showValue: false
      )
    )

    runtime.updateWidgetState(
      .spaces(
        SpacesState(
          displays: [
            .init(identifier: "a", spaces: [.init(id: 1)], activeID: 1),
            .init(
              identifier: "b",
              spaces: [.init(id: 2), .init(id: 3), .init(id: 4, fullscreen: true)],
              activeID: 3
            ),
          ],
          focusedID: 1
        )
      ),
      for: .spaces
    )

    #expect(runtime.tooltip(for: item, displayUUID: "B") == "Code: 2/2\n1, Code")
    #expect(runtime.tooltip(for: item, displayUUID: "A") == "1: 1/1\n1")
    #expect(runtime.tooltip(for: item, displayUUID: "missing") == "—: —/—\n—")
  }

  @Test("command and plugin tokens preserve full output and follow keep-last behavior")
  func commands() throws {
    let output = try CommandState.decode(
      #"{"text":"Long output\n{status}"}"#,
      configuration: ShellCommand(script: "echo", format: .json)
    )
    let command = Item(
      id: "command",
      type: .command,
      tooltip: "{output}\n{status}: {error}",
      command: ShellCommand(script: "echo", maxLength: 4, onError: .keepLast, showValue: false)
    )
    let state = CommandState(status: .failure, lastSuccess: output, error: "Failed")
    let template = try TooltipTemplate(command.tooltip ?? "", type: .command)

    #expect(
      template.render(values: state.presentation(for: command).tooltipValues)
        == "Long output\n{status}\nfailure: Failed"
    )

    let plugin = Item(
      id: "plugin",
      type: .plugin,
      plugin: Plugin(executable: "/example", onError: .keepLast)
    )

    #expect(
      PluginState(status: .failure, lastSuccess: output, error: "Failed").presentation(for: plugin)
        .tooltipValues
        == state.presentation(for: command).tooltipValues
    )

    var discarded = command
    discarded.command?.onError = .show

    #expect(state.presentation(for: discarded).tooltipValues["output"] == "")
  }

  @Test("application names are independent of labels")
  func applicationNames() {
    let runtime = ProviderRuntime()
    runtime.updateFrontApplication(.init(name: "Terminal", icon: nil))

    let item = Item(id: "app", type: .frontApplication, label: "App", tooltip: "{name}: {text}")

    #expect(runtime.tooltip(for: item) == "Terminal: App")
  }
}
