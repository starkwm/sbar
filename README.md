# sbar

Stark Bar for macOS.

`sbar` is a configurable status bar with native system information, shell commands, and process plugins. Arrange items across the left, center, and right of each display, and control the running bar from the command line.

## Requirements

- macOS 26 or later
- Xcode 26 or later when building from source (Swift 6.2)

## Installation

Build from source:

```sh
git clone https://github.com/starkwm/bar.git
cd bar
make build
```

The development binary is written to `.build/debug/sbar`. Run it to start the bar:

```sh
.build/debug/sbar
```

Use `make release` for an optimized build in `.build/release`. Keep the generated `sbar_SbarCore.bundle` alongside the executable when copying build outputs. Add the executable's directory to your `PATH` to use the `sbar` commands below.

A source build is not installed as a background service automatically. To run at login, create a Launch Agent that starts the executable using its absolute path.

## How commands work

Run `sbar` without a subcommand to start the bar. `sbar start` is the explicit equivalent:

```sh
sbar [start] [--config <path>]
```

Other invocations send commands to the running process. `validate` checks a configuration file independently. Commands return a nonzero exit status on failure. Run `sbar --help` or `sbar <command> --help` for help.

Client commands connect to `~/.config/starkbar/control.sock`. An instance started with `--config` creates `control.sock` beside that file. Pass `--socket <path>` after the client subcommand to target it:

```sh
sbar start --config /path/to/config.json
# In another terminal:
sbar query --socket /path/to/control.sock
```

Only one instance can own a given socket, and clients must run as the same user.

## Configuration

Edit `~/.config/starkbar/config.json` in your preferred editor. sbar reloads it when the file changes. Missing files use built-in defaults (the active application, a divider, and a clock); invalid edits retain the last valid configuration. Inspect errors with `sbar query --diagnostics`.

Run `sbar validate` (or `sbar validate --config /path/to/config.json`) to check a file without starting the bar. Invalid or missing files produce an error and a nonzero exit status. Validation never writes the file. Use `sbar start --config /path/to/config.json` to run with another configuration.

The config file is the only persistent configuration source. sbar never saves, rewrites, or backs it up. For editor completion, copy [config.schema.json](Sources/SbarCore/Resources/config.schema.json) beside your configuration and add `"$schema": "config.schema.json"` to the root object.

For a larger example with native metrics, popups, actions, commands, and a streaming plugin, see the [demo configuration](examples/demo/README.md). For a minimal top bar with inset edges and rounded corners, see the [floating demo](examples/floating/README.md).

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

### Bar settings

| Property | Values | Default |
| --- | --- | --- |
| `position` | `top` or `bottom` | `top` |
| `height` | 20–96 points, including content padding | `32` |
| `margin` | Object with `top`, `bottom`, `left`, `right` offsets (0–4096 points each) | All `0` |
| `displays` | `main`, `all`, or `selected` | `all` |
| `displayIDs` | Display IDs, required when `displays` is `selected` | None |
| `windowLevel` | `floating`, `statusBar`, or `screenSaver` | `statusBar` |
| `mousePassThrough` | Pass mouse events through empty regions | `false` |

`main` selects the primary display. Use `sbar query --displays` to find connected display IDs and names.

Top placement uses the physical screen edge, sharing the system menu-bar area. Bottom placement respects the Dock's visible work area. On notched displays, items avoid the cutout and the center section sits immediately to its right.

For a floating bar, inset the panel and round its background:

```json
{
  "schemaVersion": 1,
  "bar": {
    "height": 40,
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

### Items

`items.left`, `items.center`, and `items.right` are arrays in display order. Omitted sections are empty. Each item requires a `type` and a nonblank `id`, unique across every section and nested group.

| Type | Content |
| --- | --- |
| `text` | Static text from `label` |
| `datetime` | Current date and/or time; custom `format` or localized `dateStyle` and `timeStyle` |
| `frontApplication` | Active application's name, or a fixed `label` |
| `battery` | Battery charge and power state |
| `volume` | Output volume and mute state |
| `network` | Network connection state |
| `wifi` | Wi-Fi connection state |
| `cpu` | CPU usage |
| `memory` | Memory usage |
| `disk` | Free space on the home volume |
| `throughput` | Network transfer rates |
| `media` | Music or Spotify playback information |
| `spaces` | Focused native macOS Space |
| `aerospace`, `yabai` | Focused workspace from the corresponding window manager |
| `command` | Output from a shell command |
| `plugin` | Text streamed by an external process |
| `group` | Inline child items |
| `popup` | A label that opens child items in a popover |
| `divider` | Vertical separator |
| `spacer` | Flexible empty space |

`datetime` items default to the system’s short time style. Use `format` for a Unicode date/time pattern:

```json
{ "id": "date", "type": "datetime", "format": "yyyy-MM-dd" }
```

For example, `dd/MM/yyyy` gives a numeric day/month/year, `EEEE, d MMMM` includes the full weekday and month names, and `MMM d 'at' HH:mm` includes the time. Patterns use the system locale and time zone; quote literal words with single quotes. Use `yyyy` for the calendar year (`YYYY` is the week-based year). A nonempty `format` overrides `dateStyle` and `timeStyle`. Omitting `format`, setting it to `null`, or using an empty string uses those styles. You can also change it at runtime with `sbar set date format '"EEEE, d MMMM"'`.

For localized formatting, `dateStyle` and `timeStyle` each accept `none`, `short`, `medium`, `long`, or `full`. They default to `none` and `short`, respectively. Set `timeStyle` to `none` for a date-only display:

```json
{ "id": "date", "type": "datetime", "dateStyle": "full", "timeStyle": "none" }
```

Both style properties can also be changed with `sbar set`.

Optional properties include `enabled` (default `true`), `label`, `symbol` (an SF Symbol name or font glyph object), `priority` (default `0`), `style`, `refresh`, `primaryAction`, `secondaryAction`, and `popup` text. Symbols appear beside item content except for groups, dividers, and spacers. Type-specific settings are described below.

### Refresh policies

`refresh` accepts `mode: event`, `interval`, or `manual`, with `seconds` (1–86,400) required for intervals and an optional named `event`. Native event mode follows provider changes; interval/manual modes snapshot shared provider values. Triggering the item ID or its event captures a fresh snapshot. Underlying metric sampling remains shared at two-second resolution. Plugins retain their own streaming cadence and receive all runtime triggers.

## Themes and item styling

The optional top-level `theme` sets bar appearance and default item styling. Each item's `style` overrides individual theme fields. Omitted or null fields inherit; explicit zero padding and transparent colors override inherited values.

```json
{
  "schemaVersion": 1,
  "bar": {},
  "theme": {
    "background": "#18202EEE",
    "horizontalPadding": 12,
    "itemSpacing": 8,
    "itemStyle": {
      "tint": "#E5E9F0",
      "fontSize": 13,
      "fontWeight": "medium",
      "horizontalPadding": 6,
      "verticalPadding": 2,
      "cornerRadius": 4
    }
  },
  "items": {
    "right": [
      {
        "id": "clock",
        "type": "datetime",
        "symbol": "clock",
        "format": "HH:mm",
        "style": { "tint": "#88C0D0", "background": "#FFFFFF18" }
      }
    ]
  }
}
```

Colors use `#RRGGBB` or `#RRGGBBAA` (alpha last). An omitted bar background uses the system material. An omitted item tint uses the system primary color; item backgrounds default to transparent. Use `#00000000` to clear an inherited background.

Item styles support `tint`, `background`, `fontSize` (8–72 points), `fontWeight` (`regular`, `medium`, `semibold`, `bold`), `horizontalPadding` (0–96), `verticalPadding` (0–48), and `cornerRadius` (0–48). Use `symbolFontWeight` (the same weight values) to override SF Symbol weight independently of text, either in `theme.itemStyle` or an item’s `style`. For example, `"style": {"symbolFontWeight": "bold"}`. Item values override the theme; when neither sets it, symbols inherit the resolved text weight. This also applies to battery and Wi-Fi state symbols; font glyphs keep their custom font. Defaults are 13-point regular text with no item padding or corner radius. The theme's bar `horizontalPadding` and `itemSpacing` default to 10 points and accept 0–96. Oversized content stays clipped to its bar region; styling does not increase bar height.

## Native items

`frontApplication`, `battery`, `volume`, `network`, and `wifi` use native change notifications. `cpu`, `memory`, `disk`, and `throughput` sample once every two seconds, shared across displays. All `datetime` items share one clock. Memory reports active, wired, and compressed pages; disk reports free space on the home volume. Throughput totals non-loopback interfaces, so tunnels may contribute additional traffic. Fixed-volume outputs display that status rather than a fabricated percentage.

`media` listens for Music and Spotify playback notifications. It waits for the next notification after startup and does not query or control other players. Wi-Fi reports connection state, not the location-protected SSID.

### Font glyph symbols

Every `symbol`, including battery and Wi-Fi state symbols, accepts either an SF Symbol name
or a glyph object. Install the font on your Mac first and use its font name:

```json
{
  "id": "wifi",
  "type": "wifi",
  "wifi": {
    "showLabel": false,
    "connectedSymbol": { "glyph": "\uf1eb", "font": "Symbols Nerd Font Mono" },
    "disconnectedSymbol": "wifi.slash"
  }
}
```

`glyph` is literal text (JSON Unicode escapes work too), `font` selects the installed font,
and optional `size` accepts 8–72 points. Without `size`, glyphs use the resolved item/theme
font size. Only the symbol uses the custom font; item text retains its normal font. Missing
fonts or glyphs use macOS font fallback, which may display a missing-character box.
SF Symbol strings continue to work, and can be mixed with glyph objects.

Battery `symbols.levels` accepts exactly five symbols, ordered 0%, 25%, 50%, 75%, 100%:

```json
{
  "id": "battery",
  "type": "battery",
  "battery": {
    "symbols": {
      "font": "Symbols Nerd Font Mono",
      "levels": [
        { "glyph": "\uf244" },
        { "glyph": "\uf243" },
        { "glyph": "\uf242" },
        { "glyph": "\uf241" },
        { "glyph": "\uf240" }
      ],
      "charging": { "glyph": "\uf0e7" }
    }
  }
}
```

Within `battery.symbols`, glyphs inherit `font` and optional `size` (8–72 points).
Each glyph can override either value. A font must be provided locally or inherited;
without either size, the resolved item/theme font size is used. Strings remain SF Symbol
names and do not inherit glyph font settings. Omitted state symbols use the built-in defaults.

An item-level `symbol` overrides all state symbols;
`showSymbol: false` hides the symbol regardless of these settings.

The existing transient `set` command also accepts a glyph object for the item-level `symbol`.

### Frontmost application icon

Set `frontApplication.showIcon` to show the active application's native colour icon:

```json
{ "id": "app", "type": "frontApplication", "frontApplication": { "showIcon": true } }
```

This defaults to `false`. The icon replaces the item's `symbol`; if macOS provides no icon,
the configured symbol is used as a fallback. Its size follows the resolved item font size (`style.fontSize`, then the theme font size).
The icon and application name follow the item's refresh policy together. A fixed `label`
still overrides the name; use `"label": ""` for an icon-only item.

### Battery and Wi-Fi appearance

Without widget settings, battery and Wi-Fi retain their text presentation and optional static `symbol`.
Add a `battery` or `wifi` block to enable state-dependent icons:

```json
{
  "id": "battery",
  "type": "battery",
  "battery": {
    "showPercentage": false,
    "lowThreshold": 20,
    "tints": {
      "low": "#FF6655",
      "charging": "#66CC88"
    },
    "symbols": { "pluggedIn": "powerplug" }
  }
}
```

Battery settings: `showPercentage` and `showSymbol` default to `true`. The icon follows charge
level in 25% steps, uses `symbols.charging` (default `battery.100percent.bolt`) while charging,
and `symbols.pluggedIn` (default `powerplug`) on AC power without charging. `lowThreshold`
defaults to 20 and accepts 0–100, inclusive. `tints.low` applies at or below that threshold
while running on battery; `tints.charging` and `tints.pluggedIn` apply to their respective power
states. A computer without a battery displays `AC power` and the plugged-in icon.

```json
{
  "id": "wifi",
  "type": "wifi",
  "wifi": {
    "showLabel": false,
    "connectedTint": "#66CC88",
    "disconnectedTint": "#FF6655",
    "hideWhenDisconnected": true
  }
}
```

Wi-Fi settings: `showLabel` and `showSymbol` default to `true`; `hideWhenDisconnected` defaults
to `false`. Customize `connectedLabel` / `disconnectedLabel` (defaults `Wi-Fi connected` /
`Wi-Fi disconnected`) and `connectedSymbol` / `disconnectedSymbol` (defaults `wifi` /
`wifi.slash`). Connection means the current satisfied network path uses Wi-Fi; it does not
report radio power, association, SSID, or signal strength. Ethernet taking over the path can
therefore make this widget report disconnected.

For either widget, an item-level `symbol` overrides the dynamic symbol, while `showSymbol: false`
hides it. State colors override `style.tint` when supplied; otherwise the normal item/theme tint
applies. Colors accept `#RRGGBB` or `#RRGGBBAA`. Icon-only widgets retain an accessibility label.
Refresh policies capture text, symbols, colors, and visibility together. Edit these settings in
the configuration file and reload; the `set` command does not accept the widget blocks.


## Actions

Items accept `primaryAction` and `secondaryAction` objects with `kind` (`command`, `url`, or `application`) and `value`. Primary actions run on click; secondary actions appear in the context menu. URL actions allow HTTP, HTTPS, and mailto. Application values are bundle IDs or paths; `${NAME}` and `~` expand in URL/application paths. Shell actions use `/bin/sh -c` and inherit the environment.

```json
{
  "id": "settings",
  "type": "text",
  "label": "Settings",
  "primaryAction": { "kind": "application", "value": "com.apple.systempreferences" },
  "secondaryAction": { "kind": "command", "value": "open -a 'Activity Monitor'" }
}
```

## Shell commands

A `command` item requires `command: {"script":"date", "timeout":5}`. Add `refresh: {"mode":"interval", "seconds":10, "event":"refresh"}` to rerun periodically or on that trigger. Without a refresh interval, it runs once at startup and when triggered by its ID. Commands have a 64 KB combined output limit, a default five-second timeout, and terminate their process group on timeout, cancellation, or completion.

```json
{
  "id": "hostname",
  "type": "command",
  "command": { "script": "hostname -s", "timeout": 5 },
  "refresh": { "mode": "interval", "seconds": 60, "event": "refresh" }
}
```

`command.timeout` accepts 0.1–60 seconds.

## Groups and popups

`group` items render `children` inline. `popup` items show `children` when clicked; any item can also have a `popup` text string. Groups nest up to eight levels. Disabling a group disables its child providers.

```json
{
  "id": "system",
  "type": "popup",
  "label": "System",
  "children": [
    { "id": "cpu", "type": "cpu" },
    { "id": "memory", "type": "memory" }
  ]
}
```

### Overflow

Each region measures its items, allows flexible text to compress, and moves low-priority items into an overflow popover when space runs out. Larger `priority` values remain visible longer; equal priorities hide from the end. On displays without a notch, the center reserves one third of the bar when populated. Beside a notch, the center and right sections share the usable right-hand area. Bar content stays clipped within its own region.

## Runtime control

### Query state

```sh
sbar query [--diagnostics | --displays] [--socket <path>]
```

`query` returns the running configuration as JSON. `--diagnostics` returns the configuration path, current configuration error, last action error, and up to 100 recent runtime events. `--displays` returns connected display IDs, names, and whether each is primary. The two selectors are mutually exclusive.

### Reload configuration

```sh
sbar reload [--socket <path>]
```

Reload the file immediately. Invalid configuration returns an error and retains the last valid configuration.

### Update items

```sh
sbar set <item-id> <property> <value> [--socket <path>]
```

Values are parsed as JSON when possible, otherwise as strings. For example:

```sh
sbar set clock enabled false
sbar set clock style '{"tint":"#88C0D0"}'
```

`set` changes in-memory configuration only. Supported properties are `label`, `symbol`, `enabled`, `priority`, `format`, `dateStyle`, `timeStyle`, `style`, and `popup`. Edit the config file to make changes persistent. Reload or restart discards transient changes.

### Trigger events

```sh
sbar trigger <event> [<json>] [--socket <path>]
sbar trigger refresh '{"source":"manual"}'
```

Matching item IDs or refresh event names update native snapshots or rerun command items. Plugins receive all triggers. The optional payload must be valid JSON and is included in runtime events and plugin input.

### Subscribe to events

```sh
sbar subscribe [--socket <path>]
```

Streams JSON lines for configuration changes, provider values, and triggers until interrupted. Slow subscribers are disconnected.

### Stop the bar

```sh
sbar stop [--socket <path>]
```

`stop` acknowledges the request, then shuts down the bar, stops providers and child processes, closes panels, and removes the control socket. Use `--socket` to target an instance started with a custom configuration directory.

## Process plugins

A `plugin` item uses `plugin: {"executable":"/absolute/path/to/provider", "arguments":[], "restart":true}`. `${NAME}` and `~` expand in the executable path. The provider receives newline-delimited JSON on stdin: `{"version":1,"event":"start"}` initially, then runtime trigger events with an optional `value`. It emits `{"text":"display text"}` lines on stdout. stderr is discarded. Flush stdout after each update.

Each output line is limited to 64 KB and displayed text to 4,096 characters. Bursts coalesce to the latest value in each read. The input mailbox holds up to 32 events and drops new events if full. Invalid output stops that process; automatic restarts back off from one to 30 seconds. Set `restart:false` for one-shot providers. Removing/disabling the item or shutting down terminates the process group.

## Workspaces

`aerospace` and `yabai` items show the focused workspace. Executables are located in PATH or the standard Homebrew prefixes. Queries run every two seconds with a two-second timeout; missing or unavailable integrations show a status message. No adapter changes window-manager configuration.

A `spaces` item shows the focused native macOS Space, without a window-manager integration:

```json
{"id": "spaces", "type": "spaces", "symbol": "rectangle.3.group"}
```

The number is a one-based position in WindowServer's current Space ordering across displays, including fullscreen Spaces. It can change when Spaces are reordered, added, or removed. All bars show the focused Space rather than a separate value for each display. The provider refreshes on Space switches, application activation, and display changes. It uses private SkyLight APIs and shows `Spaces unavailable` if those APIs or the current Space cannot be read.

The app pauses providers and commands during sleep and restarts them after wake. Panels follow screen and Space changes.

## Development

```sh
make build    # Debug build
make release  # Optimized build
make test     # Run tests
make format   # Format Swift sources
make lint     # Check Swift formatting
make clean    # Remove build products
```
