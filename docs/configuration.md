# Configuration

[Documentation index](index.md)

Edit `~/.config/starkbar/config.json` in your preferred editor. sbar reloads it when the file changes. Missing files use built-in defaults (the active application, a divider, and a clock); invalid edits retain the last valid configuration. Inspect errors with `sbar query --diagnostics`.

Run `sbar validate` (or `sbar validate --config /path/to/config.json`) to check a file without starting the bar. Invalid or missing files produce an error and a nonzero exit status. Validation never writes the file. Use `sbar start --config /path/to/config.json` to run with another configuration.

The config file is the only persistent configuration source. sbar never saves, rewrites, or backs it up. For editor completion, copy [config.schema.json](../Sources/SbarCore/Resources/config.schema.json) beside your configuration and add `"$schema": "config.schema.json"` to the root object.

For a daily-use bar with app shortcuts, system status popovers, and volume controls, see the [Everyday bar](../examples/everyday/README.md). For a minimal top bar with inset edges and rounded corners, see the [floating bar](../examples/floating/README.md).

Create `~/.config/starkbar/config.json` with a configuration such as:

```json
{
  "schemaVersion": 1,
  "bar": {},
  "items": {
    "left": [
      { "id": "app", "type": "frontApplication" }
    ],
    "right": [
      { "id": "battery", "type": "battery" },
      { "id": "clock", "type": "datetime", "format": "HH:mm" }
    ]
  }
}
```

Only `schemaVersion: 1` is supported.

## Bar settings

| Property | Values | Default |
| --- | --- | --- |
| `position` | `top` or `bottom` | `top` |
| `height` | 20–96 points, including content padding | `32` |
| `margin` | Object with `top`, `bottom`, `left`, `right` offsets (0–4096 points each) | All `0` |
| `displays` | `main`, `all`, or `selected` | `all` |
| `displayIDs` | Display IDs, required when `displays` is `selected` | None |
| `windowLevel` | `floating`, `statusBar`, or `screenSaver` | `floating` |
| `shadow` | Draw a shadow outside the bar | `false` |
| `mousePassThrough` | Pass mouse events through empty regions | `false` |

`main` selects the primary display. Use `sbar query --displays` to find connected display IDs and names.

Top placement uses the physical screen edge, sharing the system menu-bar area. Bottom placement respects the Dock's visible work area. On notched displays, items avoid the cutout and the center section sits immediately to its right.

The default `floating` window level keeps the bar above ordinary windows and below system notifications and the revealed menu bar. Omitting `windowLevel` or setting it to `null` uses this default. Explicit `statusBar` and `screenSaver` levels can cover notifications, especially when the menu bar auto-hides and banners overlap the bar.

For a floating bar, inset the panel, round its background, and enable its shadow:

```json
{
  "schemaVersion": 1,
  "bar": {
    "height": 40,
    "shadow": true,
    "margin": { "top": 44, "left": 12, "right": 12 }
  },
  "theme": {
    "horizontalPadding": 16,
    "verticalPadding": 4,
    "cornerRadius": 12
  },
  "items": { "right": [{ "id": "clock", "type": "datetime", "format": "HH:mm" }] }
}
```

Margins inset the placement area: top bars anchor to its top edge, bottom bars to its bottom edge. Left and right margins control width independently. Excessive margins clamp to leave at least one point of available area; height shrinks to fit. A top margin is measured from the physical screen edge, so choose enough clearance for your display's notch/menu bar. Notch avoidance stops once the panel is below the cutout. These settings reload automatically when the configuration file changes.

The theme's `verticalPadding` and `cornerRadius` accept 0–48 points and default to zero. Padding sits inside `bar.height`; the rounded shape clips both material/custom backgrounds and content.

Set `bar.shadow` to `true` for a raised appearance. It defaults to `false`; `null` also uses that default. Inset or rounded bars use the native macOS window shadow, whose color, blur, and offset are controlled by the system. Square bars spanning the display's full width use a soft 16-point fade below a top bar or above a bottom bar, avoiding the native window's thin outline. The fade shortens if it reaches the screen edge.

The shadow does not change the bar's configured height, content position, or mouse hit regions. The edge fade uses extra transparent window space that always passes clicks through. Shadow changes reload automatically, including after edits to the margins, background, or corner radius.

## Items

`items.left`, `items.center`, and `items.right` are arrays in display order. Omitted sections are empty. Each item requires a `type` and a nonblank `id`, unique across every section and nested group.

| Type | Content |
| --- | --- |
| `text` | Static text from `label` |
| [`datetime`](providers/datetime.md) | Current date and/or time; custom `format` or localized `dateStyle` and `timeStyle` |
| [`frontApplication`](providers/front-application.md) | Application owning the menu bar, or a fixed `label` |
| [`battery`](providers/battery.md) | Battery charge and power state |
| [`volume`](providers/volume.md) | Output volume and mute state |
| [`audioDevice`](providers/audio-device.md) | Default audio output or input device name |
| [`network`](providers/network.md) | Network connection state |
| [`mail`](providers/mail.md) | Apple Mail combined inbox unread count |
| [`vpn`](providers/vpn.md) | VPN connection names and status |
| [`bluetooth`](providers/bluetooth.md) | Bluetooth power, connected devices, and access status |
| [`cpu`](providers/cpu.md) | CPU usage |
| [`memory`](providers/memory.md) | Memory usage |
| [`disk`](providers/disk.md) | Capacity of a selected volume (home volume by default) |
| [`throughput`](providers/throughput.md) | Network transfer rates |
| [`media`](providers/media.md) | Music or Spotify playback information |
| [`spaces`](providers/spaces.md) | Focused native macOS Space |
| [`aerospace`](providers/aerospace.md), [`yabai`](providers/yabai.md) | Focused workspace from the corresponding window manager |
| [`command`](providers/command.md) | Output from a shell command |
| [`plugin`](providers/plugin.md) | Text streamed by an external process |
| [`group`](layout.md) | Inline child items |
| [`popup`](layout.md) | A label that opens child items in a popover |
| [`divider`](layout.md#dividers-and-spacers) | Vertical separator |
| [`spacer`](layout.md#dividers-and-spacers) | Flexible empty space |

Optional properties include `enabled`, `label`, [`symbol` and `symbolPosition`](symbols.md), `priority`, [`style`](styling.md), [`refresh`](#refresh-policies), [`primaryAction` and `secondaryAction`](actions.md), and [`popup` text](layout.md). `enabled` defaults to `true` and `priority` defaults to `0`.

Symbols accept SF Symbol names or font glyph objects and appear beside item content except for groups, dividers, and spacers. `symbolPosition` accepts `left` or `right` and defaults to `left`. It also controls provider state symbols and frontmost application icons. Follow the provider links in the table for type-specific settings.

## Refresh policies

`refresh` accepts `mode: event`, `interval`, or `manual`, with `seconds` (1–86,400) required for intervals and an optional named `event`. Native event mode follows provider changes; interval/manual modes snapshot shared provider values. Triggering the item ID or its event captures a fresh snapshot. Underlying metric sampling remains shared at two-second resolution. Plugins retain their own streaming cadence and receive all runtime triggers.

`frontApplication`, `battery`, `volume`, `audioDevice`, `network`, `vpn`, and `bluetooth` use native change notifications. `cpu`, `memory`, `disk`, and `throughput` sample once every two seconds, shared across displays. All `datetime` items share one clock. See each [provider's documentation](index.md#providers) for its update behavior.

The app pauses providers and commands during sleep and restarts them after wake. Panels follow screen and Space changes.

Use the [CLI](cli.md#trigger-events) to trigger refreshes and [subscribe to events](cli.md#subscribe-to-events).
