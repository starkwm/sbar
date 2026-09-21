# Configuration

[Documentation index](index.md)

By default, sbar looks for `~/.config/sbar/config.jsonc`, then `~/.config/sbar/config.json`. Edit either file in your preferred editor. sbar reloads it when the file changes. Missing files use built-in defaults (the active application, a divider, and a clock); invalid edits retain the last valid configuration. Inspect errors with `sbar query --diagnostics`.

Run `sbar validate` (or `sbar validate --config /path/to/config.json`) to check a file without starting the bar. Invalid or missing files produce an error and a nonzero exit status. Validation never writes the file. Use `sbar start --config /path/to/config.json` to run with another configuration.

Configuration files accept JSONC comments (`//` to the end of a line and `/* ... */` blocks) and trailing commas in objects and arrays. sbar strips these in memory before decoding; your file keeps its comments and formatting. Comment markers inside strings are preserved. Block comments cannot be nested.

Both `.json` and `.jsonc` files support this syntax. Both `sbar start` and `sbar validate` prefer `config.jsonc` when both default files exist. An invalid `config.jsonc` reports an error instead of falling back to `config.json`. Pass `--config /path/to/config.jsonc` to select a file explicitly.

```jsonc
{
  "schemaVersion": 1,
  // Leave room for the menu bar.
  "bar": { "margin": { "top": 40, }, },
  "items": {
    "right": [
      /* Use a 24-hour clock. */
      { "id": "clock", "type": "datetime", "format": "HH:mm", },
    ],
  },
}
```

The config file is the only persistent configuration source. sbar never saves, rewrites, or backs it up. For editor completion, copy [config.schema.json](../Sources/SbarCore/Resources/config.schema.json) beside your configuration and add `"$schema": "config.schema.json"` to the root object.

For a daily-use bar with app shortcuts, system status popovers, and volume controls, see the [Everyday bar](../examples/everyday/README.md). For a minimal top bar with inset edges and rounded corners, see the [floating bar](../examples/floating/README.md).

Create `~/.config/sbar/config.json` with a configuration such as:

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

Use the common [`text` field](text-templates.md) to customise labels with provider values and conditional sections.

## Bar settings

| Property | Values | Default |
| --- | --- | --- |
| `position` | `top`, `bottom`, `left`, or `right` | `top` |
| `height` | Horizontal bar height, 20–96 points including padding | `32` |
| `width` | Vertical bar width, 20–96 points including padding | `32` |
| `extendToTopEdge` | Extend side bars to the physical top edge, respecting the Dock and margins; ignored by horizontal bars | `false` |
| `margin` | Object with `top`, `bottom`, `left`, `right` offsets (0–4096 points each) | All `0` |
| `displays` | `main`, `all`, or `selected` | `all` |
| `displayIDs` | Display IDs, required when `displays` is `selected` | None |
| `windowLevel` | `floating`, `statusBar`, or `screenSaver` | `floating` |
| `shadow` | Draw a shadow outside the bar | `false` |
| `mousePassThrough` | Pass mouse events through empty regions | `false` |

`main` selects the primary display. Use `sbar query --displays` to find connected display IDs and names.

Top bars start at the physical screen edge and share the menu-bar area. Bottom and side bars fit within the space left by the menu bar and Dock. Set `bar.extendToTopEdge` to `true` to extend a side bar into the menu-bar area. When a top bar crosses a notch, its items avoid the cutout and its center section sits to the right of it.

Bars hide on displays showing a full-screen app and return when you switch back to a desktop Space. Bars on other displays stay visible. This applies to every bar position and window level, even without a Spaces item.

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

Margins leave space between the bar and the edges of its placement area. Left and right margins shorten horizontal bars. Top and bottom margins shorten side bars. If the margins leave less than one point, sbar clamps them and shrinks the bar to fit.

For a top bar, `margin.top` starts at the physical screen edge. Set it high enough to clear the menu bar or notch. Side bars with `extendToTopEdge` also measure `margin.top` from the physical screen edge. Other margins and positions use the usable display area. Changes reload automatically.

The theme's `verticalPadding` and `cornerRadius` accept 0 to 48 points and default to zero. Padding sits inside the bar. Rounded corners clip its background and content.

Set `bar.shadow` to `true` to add a shadow. Omitted or null values default to `false`. Inset or rounded bars use the native macOS window shadow. Square bars spanning the full display width use a 16-point fade below a top bar or above a bottom bar. Side bars spanning the full display height cast the fade towards the middle of the display. The fade shortens if it reaches the opposite screen edge.

Shadows sit outside the bar and do not move its content or click targets. The edge fade always passes clicks through.

## Vertical bars

Set `bar.position` to `left` or `right` and set the width with `bar.width`. Items stay upright and run from top to bottom on either edge.

| Section | Position in a side bar |
| --- | --- |
| `items.left` | Top |
| `items.center` | Middle |
| `items.right` | Bottom |

The matching `theme.regions` styles follow the same order.

```json
{
  "schemaVersion": 1,
  "bar": { "position": "left", "width": 64 },
  "theme": { "horizontalPadding": 4, "verticalPadding": 8 },
  "items": {
    "left": [{ "id": "spaces", "type": "spaces", "spaces": { "showSymbol": false } }],
    "right": [{ "id": "clock", "type": "datetime", "format": "HH:mm" }]
  }
}
```

`bar.width` controls side bars; `bar.height` controls top and bottom bars. Both default to 32 points and accept 20 to 96. Padding and item widths keep their usual directions. Use short labels or `"text": ""` for icons without labels. Long labels truncate to fit.

Group children and provider entries, such as a list of Spaces, stack vertically. Dividers run across the bar and spacers expand along it. [Overflow](layout.md#overflow) uses item heights and the same priority order as horizontal bars. Popups open towards the middle of the display. Items inside them keep their horizontal layout.

Side bars do not reserve space for other windows. Set a left or right gap in your window manager if needed.

See the [vertical example](../examples/vertical/README.md) for app shortcuts, status icons and popups.

## Items

`items.left`, `items.center`, and `items.right` are arrays in display order. Omitted sections are empty. Each item requires a `type` and a nonblank `id`, unique across every section and nested group.

| Type | Content |
| --- | --- |
| `text` | Static text from `text` |
| [`datetime`](providers/datetime.md) | Current date and/or time; custom `format` or localized `dateStyle` and `timeStyle` |
| [`frontApplication`](providers/front-application.md) | Application owning the menu bar, or a fixed `text` |
| [`battery`](providers/battery.md) | Battery charge and power state |
| [`volume`](providers/volume.md) | Output volume and mute state |
| [`audioDevice`](providers/audio-device.md) | Default audio output or input device name |
| [`network`](providers/network.md) | Network connection state |
| [`weather`](providers/weather.md) | Current conditions from Open-Meteo at configured coordinates |
| [`mail`](providers/mail.md) | Apple Mail combined inbox unread count |
| [`vpn`](providers/vpn.md) | VPN connection names and status |
| [`bluetooth`](providers/bluetooth.md) | Bluetooth power, connected devices, and access status |
| [`cpu`](providers/cpu.md) | CPU usage |
| [`memory`](providers/memory.md) | Memory usage |
| [`disk`](providers/disk.md) | Capacity of a selected volume (home volume by default) |
| [`throughput`](providers/throughput.md) | Network transfer rates |
| [`media`](providers/media.md) | Music or Spotify playback information |
| [`spaces`](providers/spaces.md) | Native macOS Spaces with optional text or icon name overrides |
| [`aerospace`](providers/aerospace.md), [`yabai`](providers/yabai.md) | Focused workspace from the corresponding window manager |
| [`command`](providers/command.md) | Output from a shell command |
| [`plugin`](providers/plugin.md) | Text streamed by an external process |
| [`group`](layout.md) | Inline child items |
| [`popup`](layout.md) | A label that opens child items in a popover |
| [`divider`](layout.md#dividers-and-spacers) | Separator across the bar |
| [`spacer`](layout.md#dividers-and-spacers) | Flexible empty space |

Optional properties include `enabled`, [`text`](text-templates.md), [`symbol` and `symbolPosition`](symbols.md), `priority`, [`style`](styling.md), [`refresh`](#refresh-policies), [`primaryAction` and `secondaryAction`](actions.md), and [`popup` text](layout.md). `enabled` defaults to `true` and `priority` defaults to `0`.

Symbols accept SF Symbol names or font glyph objects and appear beside item content except for groups, dividers, and spacers. `symbolPosition` accepts `left` or `right` and defaults to `left`. It also controls provider state symbols and frontmost application icons. Follow the provider links in the table for type-specific settings.

For macOS Spaces, [`spaces.names`](providers/spaces.md#name-overrides) sets a label for each position. Use a string for text, `{ "symbol": "globe" }` for an SF Symbol, or `{ "symbol": { "glyph": "\uf121", "font": "Symbols Nerd Font Mono" } }` for a font glyph. Missing, `null`, and empty entries keep the default number. These labels also appear in workspace templates.

## Refresh policies

`refresh` accepts `mode: event`, `interval`, or `manual`, with `seconds` (1–86,400) required for intervals and an optional named `event`. Native event mode follows provider changes; interval/manual modes snapshot shared provider values. Triggering the item ID or its event captures a fresh snapshot. Underlying metric sampling remains shared at two-second resolution. Plugins retain their own streaming cadence and receive all runtime triggers.

`frontApplication`, `battery`, `volume`, `audioDevice`, `network`, `vpn`, and `bluetooth` use native change notifications. `cpu`, `memory`, `disk`, and `throughput` sample once every two seconds, shared across displays. All `datetime` items share one clock. See each [provider's documentation](index.md#providers) for its update behavior.

The app pauses providers and commands during sleep and restarts them after wake. Panels follow screen and Space changes.

Use the [CLI](cli.md#trigger-events) to trigger refreshes and [subscribe to events](cli.md#subscribe-to-events).
