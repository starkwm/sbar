# Native macOS Bar App Plan

Build a fully customizable macOS bar app using SwiftUI for rendering and configuration, with a narrow AppKit layer for desktop-level window behavior. Take inspiration from Zebar's provider/configuration model and SketchyBar's dynamic items, events, and scripting without using web views as the primary renderer.

## Core model

```text
BarConfiguration
├── appearance
├── placement: top | bottom
├── displays: main | all | selected
└── sections
    ├── left:   [ItemConfiguration]
    ├── center: [ItemConfiguration]
    └── right:  [ItemConfiguration]
```

Each item has:

- Stable ID, type, and enabled state
- Section and ordering
- Icon, label, tint, font, padding, and background
- Refresh policy: event-driven, interval, or manual
- Primary and secondary click actions
- Optional popup configuration
- Type-specific settings

Use three customization layers:

1. Built-in defaults
2. Global theme tokens
3. Per-item overrides

## Runtime design

- `BarApp`: lifecycle, menu bar extra, and Settings scene
- `BarCoordinator`: creates one bar panel per selected display
- `BarPanel`: thin `NSPanel` subclass hosting SwiftUI
- `BarView`: composes three independently aligned regions
- `ConfigurationStore`: loads, validates, observes, and saves configuration
- `ProviderRegistry`: owns and shares system-data providers
- `ActionRunner`: handles clicks, commands, URLs, and app launches
- `EventBus`: distributes typed provider and system events
- `PopupCoordinator`: presents interactive item popups

Use three overlaying layout regions rather than a simple `HStack` with spacers:

```text
| left items →       | ← centered on screen → |       ← right items |
```

This keeps the center geometrically centered when the side regions have different widths. Overflow handling should:

1. Compress flexible items
2. Hide low-priority items
3. Expose hidden items in an overflow popup

## Native window behavior

Use `NSPanel` because a persistent desktop bar needs behavior SwiftUI scenes alone cannot reliably provide:

- Borderless, transparent, non-activating window
- Configurable floating window level
- One panel per `NSScreen`
- `.canJoinAllSpaces`, `.stationary`, and `.fullScreenAuxiliary`
- Exclusion from window cycling
- Repositioning after screen/layout changes
- Optional mouse pass-through for empty regions
- No Dock or Command-Tab presence through `LSUIElement`
- Separate normal Settings window

SwiftUI remains the source of truth. AppKit owns only panel lifecycle and placement.

Do not claim the macOS menu-bar work area in the first release. Public SDKs do not expose a clean supported equivalent of the Dock's reserved screen region. Test fullscreen apps, Stage Manager, Spaces, and multiple displays explicitly.

## Built-in items

Initial item set:

- Clock and date
- Battery and power source
- Volume
- Wi-Fi and network status
- CPU, memory, disk, and network throughput
- Current application
- Media playback
- Spacer and divider
- Static text or SF Symbol
- Shell-command output
- Workspace adapters for AeroSpace and yabai
- Group and popup items

Provider shape:

```swift
protocol BarProvider: AnyObject {
    associatedtype Value: Sendable
    var updates: AsyncStream<Value> { get }
    func start() async throws
    func stop() async
}
```

Prefer native frameworks and notifications over polling. Poll only metrics without suitable events. Share provider instances so multiple displays do not duplicate system sampling.

## Configuration

Start with a versioned JSON or JSON5 configuration file:

```json
{
  "schemaVersion": 1,
  "bar": {
    "position": "top",
    "height": 32,
    "displays": "all"
  },
  "items": {
    "left": [
      { "id": "app", "type": "frontApplication" }
    ],
    "center": [
      { "id": "media", "type": "media" }
    ],
    "right": [
      { "id": "battery", "type": "battery" },
      { "id": "clock", "type": "clock", "format": "HH:mm" }
    ]
  }
}
```

Support:

- Live reload through filesystem observation
- Atomic writes and automatic backups
- Bundled JSON Schema
- Validation errors with precise coding paths
- Migration based on `schemaVersion`
- Environment-variable expansion in action paths
- Standard user configuration directory and optional `--config` override

Add a GUI editor after the file format stabilizes. It should offer drag-and-drop between left, center, and right; live preview; an item inspector; theme editing; validation; import/export; and a reveal-config action.

## Extensibility

Use two extension levels:

- First-party native providers compiled into the app
- External process plugins using newline-delimited JSON over stdin/stdout

Do not load arbitrary Swift bundles initially. They introduce signing, ABI, security, and crash-isolation problems. Process plugins retain SketchyBar-style flexibility while isolating failures.

Provide a small command-line interface:

```text
barctl query
barctl reload
barctl trigger <event> [json]
barctl set <item-id> <property> <value>
barctl subscribe
```

This enables dynamic mutation and event integration without making shell scripts the rendering engine.

## Suggested project structure

```text
Bar.xcodeproj
Sources/
  App/
  Models/
  Views/Bar/
  Views/Settings/
  Windowing/
  Configuration/
  Providers/
    System/
    Integrations/
  Actions/
  Plugins/
  IPC/
  Support/
Tests/
  ConfigurationTests/
  LayoutTests/
  ProviderTests/
  IPCTests/
```

Initially target macOS 14. Use Swift 6 concurrency, Observation, `Codable`, `OSLog`, and Swift Testing. Add older-version compatibility only when it becomes a concrete requirement.

## Delivery phases

1. **Foundation:** App lifecycle, `NSPanel`, one/all-display placement, and left/center/right renderer.
2. **Configuration:** Versioned decoding, validation, live reload, themes, and per-item styling.
3. **Native items:** Clock, battery, volume, network, CPU/memory, and front application.
4. **Interaction:** Click actions, hover states, popups, and shell commands.
5. **Runtime control:** Event bus, `barctl`, and dynamic item updates.
6. **Editor:** Native Settings window, drag-and-drop layout, preview, and diagnostics.
7. **Extensibility:** External provider protocol plus AeroSpace and yabai adapters.
8. **Hardening:** Screen changes, Spaces/fullscreen, sleep/wake, performance, accessibility, signing, and distribution.

Each phase ends with unit tests and manual coverage across multiple monitors, Spaces, fullscreen, Stage Manager, display hot-plugging, and sleep/wake.

## Unresolved questions

- Replace the system menu bar, coexist beneath it, or support both?
- Minimum supported macOS version?
- File-first configuration, GUI-first, or equal priority?
- Should shell commands and external plugins be allowed by default?
- Should displays share one layout or support display-specific layouts?
- Is App Store distribution required? Sandboxing would materially constrain commands and system integrations.

## References

- [Zebar](https://github.com/glzr-io/zebar)
- [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- [Apple: NSWindow collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- [Apple: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
