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
| `cpu` | CPU usage |
| `memory` | Memory usage |
| `disk` | Capacity of a selected volume (home volume by default) |
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

Item styles support `tint`, `background`, `fontSize` (8–72 points), `fontWeight` (`regular`, `medium`, `semibold`, `bold`), `horizontalPadding` (0–96), `verticalPadding` (0–48), and `cornerRadius` (0–48). Use `symbolFontWeight` (the same weight values) to override SF Symbol weight independently of text, either in `theme.itemStyle` or an item’s `style`. For example, `"style": {"symbolFontWeight": "bold"}`. Item values override the theme; when neither sets it, symbols inherit the resolved text weight. This also applies to battery and network state symbols; font glyphs keep their custom font. Defaults are 13-point regular text with no item padding or corner radius. The theme's bar `horizontalPadding` and `itemSpacing` default to 10 points and accept 0–96. Oversized content stays clipped to its bar region; styling does not increase bar height.

## Native items

`frontApplication`, `battery`, `volume`, and `network` use native change notifications. `cpu`, `memory`, `disk`, and `throughput` sample once every two seconds, shared across displays. All `datetime` items share one clock. Memory reports active, wired, and compressed pages; disk defaults to free space on the home volume. Throughput defaults to totaling non-loopback interfaces, so tunnels may contribute additional traffic. Fixed-volume outputs display that status rather than a fabricated percentage.

`media` listens for Music and Spotify playback notifications. It waits for the next notification after startup and does not query or control other players. Wi-Fi reports connection state, not the location-protected SSID.

### Media playback

Media tracks Music and Spotify independently using their playback notifications.
By default, it selects a playing source over paused, stopped, or unknown sources,
in that order. Among sources in the same state, the most recently received update
wins. A pause notification from one player cannot replace another playing source.

```json
{
  "id": "media",
  "type": "media",
  "media": {
    "source": "automatic",
    "showTitle": true,
    "showArtist": true,
    "separator": " — ",
    "hideWhenPaused": false,
    "hideWhenStopped": true
  }
}
```

`source` accepts `automatic` (default), `music`, or `spotify`. Explicit selection
ignores the other player for that item; different items may select different sources.
`showTitle`, `showArtist`, and `showSymbol` default to `true`. The default separator
is ` — ` and only appears between nonempty fields. Hide title and artist for an
icon alone. Accessibility retains the source, playback state, and known metadata.

Paused playback retains track details when the notification omits them. Stopped
playback and app termination clear that player's track. A new title does not inherit
the previous artist when the artist is missing. Missing visible metadata falls
back to `Playing` or `Paused`; stopped playback shows `Stopped`. Unknown or malformed
playback state shows `Playback unavailable`, rather than being treated as paused.

`hideWhenPaused` and `hideWhenStopped` default to `false` and apply to the selected
source. Customize `symbols.playing`, `symbols.paused`, `symbols.stopped`, and
`symbols.unavailable` (defaults `play.fill`, `pause.fill`, `stop.fill`, `questionmark`).
Glyphs inherit `symbols.font` and optional `symbols.size`, with per-glyph overrides.
An item-level `symbol` overrides the state symbols; `showSymbol: false` hides it.

Startup remains notification-based: `Waiting for playback` is shown until the
selected source sends an update, even if it was already playing when the bar
started. Start or change a track to populate it. This integration does not query
current playback, control players, or display artwork.

Refresh policies snapshot both players' states together. Manual/interval items
retain their track, state symbol, and visibility until refreshed, including after
a player quits. Provider events use the default automatic selection and text.

### CPU appearance and smoothing

CPU usage is the aggregate busy share across all cores, from 0–100%, sampled every
two seconds. The default widget displays a `cpu` icon and `CPU N%`, rounded to the
nearest whole percent.

```json
{
  "id": "cpu",
  "type": "cpu",
  "cpu": {
    "showLabel": false,
    "smoothingSamples": 3,
    "warningThreshold": 60,
    "highThreshold": 85,
    "tints": {
      "medium": "#EBCB8B",
      "high": "#BF616A",
      "unavailable": "#888888"
    }
  }
}
```

`showLabel`, `showPercentage`, and `showSymbol` default to `true`. Hide the label
for an icon with `N%`; hide both label and percentage for an icon alone. Use
`showSymbol: false` to retain the previous text-only appearance.

`warningThreshold` (default 60) and `highThreshold` (default 85) accept integers
from 0–100; warning must be below high. The rounded displayed percentage selects
`low` below warning, `medium` at or above warning, and `high` at or above high.
Customize these states and `unavailable` in `cpu.tints` and `cpu.symbols`.
Available states default to `cpu`; unavailable defaults to `questionmark`.
Tints fall back to the item/theme color. Symbols accept SF Symbol names or glyphs,
with shared `symbols.font` / `symbols.size` and per-glyph overrides.
An item-level `symbol` overrides state symbols; `showSymbol: false` hides it.

`smoothingSamples` accepts 1–30 (default 1, no smoothing). It averages the most
recent available samples before rounding, using fewer during warm-up. Each item
can choose its own window while sharing sampling across displays. Text, thresholds,
and accessibility all use the same smoothed percentage; raw provider events retain
the latest unsmoothed reading.

Startup, failed/unchanged samples, and sampling gaps longer than ten seconds display
`CPU —` and clear smoothing history. Failed reads and sampling restarts also reset
the counter baseline; a fresh interval is needed before showing usage again.
Icon-only widgets retain an accessibility label, including the unavailable state.
Refresh policies capture the sample history so manual/interval items retain their
entire presentation until refreshed.

### Memory appearance

Memory samples every two seconds and displays a `memorychip` icon with `RAM 8 GB`
by default. Configure its value and appearance under `memory`:

```json
{
  "id": "memory",
  "type": "memory",
  "memory": {
    "format": "usedTotal",
    "showLabel": false
  }
}
```

`format` accepts `used` (default, such as `8 GB`), `percentage` (`50%`), or
`usedTotal` (`8 GB / 16 GB`). Bytes use macOS memory formatting and percentages
round to the nearest whole percent. Total is the installed physical RAM.

`showLabel`, `showValue`, and `showSymbol` default to `true`. Hide the label
for an icon with the value; hide both label and value for an icon alone.
Set `showSymbol: false` to retain the previous text-only appearance.
Customize `symbols.available` and `symbols.unavailable` (defaults `memorychip`
and `questionmark`). Glyphs inherit `symbols.font` and optional `symbols.size`,
with per-glyph overrides. An item-level `symbol` overrides both state symbols;
`showSymbol: false` hides it.

The usage calculation remains **active + wired + compressed physical pages**,
multiplied by the host page size. This is a specific VM-counter measure, not a claim
of equivalence with Activity Monitor's “Memory Used”. It does not include every VM
category or measure memory pressure; the percentage uses this same numerator.

Startup, failed reads, or inconsistent counts display `RAM —` with an unavailable
icon, replacing the previous reading. A valid next sample restores the value.
Icon-only widgets retain used/total and percentage in their accessibility label.
Raw provider events retain used-byte formatting regardless of an item's display
mode. Refresh policies capture the full numeric state, including unavailable
readings; manual/interval items retain their snapshot until refreshed.

### Disk capacity and appearance

Disk samples every two seconds and displays an `internaldrive` icon with
`120 GB free` by default. Select a volume with an existing file or directory on it:

```json
{
  "id": "external",
  "type": "disk",
  "disk": {
    "path": "/Volumes/External",
    "format": "usedTotal",
    "warningThreshold": 20,
    "criticalThreshold": 10,
    "tints": {
      "warning": "#EBCB8B",
      "critical": "#BF616A",
      "unavailable": "#888888"
    }
  }
}
```

`path` defaults to the home directory and accepts absolute paths or `~` expansion.
It may refer to a file or directory; capacity describes its containing filesystem.
Paths on the same volume share one capacity read per sampling pass, across items
and displays. Missing paths, failed reads, or invalid capacities produce an
unavailable icon and `— unavailable`, then recover on a valid sample.

The provider checks the mount before and after reading. Once a path has produced
a valid reading, a change to a different mount point is treated as unavailable,
so an unmounted drive cannot silently turn into a reading for its parent disk.
Leftover directories under `/Volumes` are also rejected unless on that mounted
volume. This tracks the volume at a path, not a persistent physical-drive identity.

`format` accepts `free` (default), `used`, `total`, `usedTotal`, and `percentage`.
Percentage means **used** space and rounds to the nearest whole percent. Labels
are `free`, `used`, or `total` as appropriate. `showLabel`, `showValue`, and
`showSymbol` default to `true`; hide label and value for an icon-only item.
Set `showSymbol: false` to retain the previous text-only appearance.
Icon-only items retain the path, free/total capacity, and used percentage in their
accessibility label.

`warningThreshold` (default 20) and `criticalThreshold` (default 10) are percentages
**free**, from 0–100; critical must be below warning. Tints apply at or below each
threshold, with critical taking precedence. Comparison uses the unrounded free
percentage. Customize `tints.normal`, `warning`, `critical`, and `unavailable`;
omitted colors fall back to the item/theme tint.

`symbols.available` and `symbols.unavailable` default to `internaldrive` and
`questionmark`. Glyphs inherit `symbols.font` and optional `symbols.size`, with
per-glyph overrides. An item-level `symbol` overrides both states, and
`showSymbol: false` hides it.

Free and total bytes come from `FileManager.attributesOfFileSystem` using
`systemFreeSize` and `systemSize`; used is total minus free. Bytes use macOS file
size formatting. This preserves the existing free-space measurement and does not
add an estimate of reclaimable storage.

Disk value events now use each **item ID**, with free-space text regardless of
display mode. Refresh policies capture each item's full capacity state; manual
items hold their snapshot until triggered. Changing an item's path clears its old
snapshot immediately.

### Throughput interfaces and appearance

Throughput samples every two seconds, calculates download/upload deltas separately
for each non-loopback interface, then combines the rates. Configure an item with:

```json
{
  "id": "throughput",
  "type": "throughput",
  "throughput": {
    "interfaces": ["en0"],
    "unit": "bytes",
    "smoothingSamples": 3,
    "showDownload": true,
    "showUpload": true
  }
}
```

Omit `interfaces` to total all non-loopback interfaces, including tunnels.
Specify a nonempty list of unique interface names to restrict sampling results;
interface names depend on the machine and do not imply Wi-Fi or Ethernet.
Explicitly selected interfaces must all have valid readings; a missing, newly
appeared, or reset interface makes that item's reading unavailable. With no filter,
only interfaces with valid deltas contribute, and new/reset interfaces join after
a fresh interval. If none have valid deltas, the item is unavailable.
Loopback interfaces are excluded even when named explicitly.

`unit` is `bytes` (default) or `bits`. Rates scale automatically through
B/s, KiB/s, MiB/s, GiB/s for bytes, or bit/s, kbit/s, Mbit/s, Gbit/s for bits.
Values round to at most one decimal place, retaining small rates such as
`0.5 B/s`. This replaces the previous truncated, fixed `KB/s` display.

`showDownload`, `showUpload`, `showValue`, `showUnits`, and `showSymbol` default
to `true`. Hide either direction independently. Hide values for directional icons
alone; hide symbols for values alone. `showUnits: false` hides suffixes but retains
automatic scaling. Accessibility includes direction names and units even when
their visible symbols or units are hidden.

Customize `symbols.download`, `symbols.upload`, and `symbols.unavailable`
(defaults `arrow.down`, `arrow.up`, `questionmark`). Glyphs inherit `symbols.font`
and optional `symbols.size`, with per-glyph overrides. An item-level `symbol`
replaces the directional symbols with one fixed icon; `showSymbol: false` hides it.

`smoothingSamples` accepts 1–30 (default 1, no smoothing). Each interface's recent
rates are averaged before summing; fewer samples are used during warm-up.
Items can select different interfaces and windows while sharing native sampling
across displays. Provider events retain unsmoothed, all-interface rates in bytes.

Timing uses a monotonic clock. Startup, failed reads, sampling restarts, and gaps
longer than ten seconds clear baselines/history and show `—` with an unavailable
icon until a fresh interval exists. Counter decreases (reset or wraparound) and
interface identity changes reset only that interface's history, without generating
a traffic spike. Unchanged counters are a valid zero rate. Removed interfaces
are discarded immediately. Refresh policies capture the full per-interface
history, so manual/interval items retain their presentation until refreshed.

### Network symbols

Configure connection symbols and label visibility under `network`:

```json
{
  "id": "network",
  "type": "network",
  "network": {
    "showLabel": false,
    "symbols": {
      "wifi": "wifi",
      "ethernet": "cable.connector",
      "cellular": "antenna.radiowaves.left.and.right",
      "other": "network",
      "offline": "network.slash"
    }
  }
}
```

These are the default symbols, including when the `network` block is omitted.
Each value accepts an SF Symbol name or a font glyph object. Glyphs inherit
`symbols.font` and optional `symbols.size`, with per-symbol overrides.
An item-level `symbol` remains a fixed override; `network.showSymbol: false`
hides the icon, including an override.

Set `network.showLabel` to `false` to show only the symbol while retaining
the connection status for accessibility. It defaults to `true`.

The text remains `Wi-Fi`, `Connected` (Ethernet, cellular, or other), or `Offline`.
An unsatisfied path is offline; otherwise Wi-Fi takes precedence over Ethernet,
then cellular, then other when macOS reports multiple interface types.
This describes the active path, not all connected adapters, and does not identify VPNs.
Use `network.labels` and `network.tints` with the same five state keys to customize
text and colors. `showLabel` and `showSymbol` default to `true`;
`hideWhenDisconnected` defaults to `false` and hides the item in its offline state.
Refresh policies capture the connection state, text, symbol, color, and visibility together.

To monitor Wi-Fi specifically:

```json
{
  "id": "wifi",
  "type": "network",
  "network": {
    "interface": "wifi",
    "showLabel": false,
    "hideWhenDisconnected": true,
    "tints": { "wifi": "#66CC88", "offline": "#FF6655" }
  }
}
```

`interface` accepts `wifi`, `ethernet`, `cellular`, or `other`. Omit it to follow
the active connection. A different active interface is presented as `offline`
for the filtered item. Wi-Fi filtering defaults to `Wi-Fi connected` /
`Wi-Fi disconnected` and `wifi` / `wifi.slash`. It describes the active path,
not radio power, association, SSID, or signal strength.

Migration: replace `"type": "wifi"` with `"type": "network"`, rename its `wifi`
block to `network`, and add `"interface": "wifi"`. Rename `connected` /
`disconnected` symbol and tint keys to `wifi` / `offline`; move
`connectedLabel` / `disconnectedLabel` into `labels.wifi` / `labels.offline`.
Existing network items should rename `network.showConnected` to
`network.showLabel`. Set `network.showSymbol: false` to retain a text-only item.

### Font glyph symbols

Every `symbol`, including battery and network state symbols, accepts either an SF Symbol name
or a glyph object. Install the font on your Mac first and use its font name:

```json
{
  "id": "wifi",
  "type": "network",
  "network": {
    "interface": "wifi",
    "showLabel": false,
    "symbols": {
      "font": "Symbols Nerd Font Mono",
      "wifi": { "glyph": "\uf1eb" },
      "offline": "wifi.slash"
    }
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

Within `battery.symbols`, `cpu.symbols`, `disk.symbols`, `media.symbols`, `memory.symbols`, `network.symbols`, `throughput.symbols`, and `volume.symbols`, glyphs inherit `font` and optional `size` (8–72 points).
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

### Volume appearance

Volume displays text and a state-dependent icon by default. An omitted `volume` block
behaves the same as `{}`. Customize it using grouped symbols and tints:

```json
{
  "id": "volume",
  "type": "volume",
  "volume": {
    "showPercentage": false,
    "symbols": {
      "levels": [
        "speaker.fill",
        "speaker.wave.1.fill",
        "speaker.wave.2.fill",
        "speaker.wave.3.fill"
      ],
      "muted": "speaker.slash.fill"
    },
    "tints": { "muted": "#FF6655" }
  }
}
```

`symbols.levels` accepts exactly four symbols: zero (0%), low (1–33%), medium (34–66%),
and high (67–100%). The example shows the default level and mute symbols. Zero volume
and mute are separate states. `symbols.fixed` defaults to `speaker.wave.3.fill` for outputs
without a readable volume; `symbols.unavailable` defaults to `speaker.slash` when no output
is available. No output takes precedence over mute, which takes precedence over volume level.

Glyphs inherit `symbols.font` and optional `symbols.size`, with per-symbol overrides,
just like battery and network. `tints.muted`, `tints.fixed`, and `tints.unavailable` override
the normal item/theme tint in their respective states.

`showPercentage` and `showSymbol` default to `true`. Text is `Volume N%`, `Muted`,
`Fixed volume`, or `No output`; `showPercentage: false` hides all of that text for an
icon-only widget while retaining its accessibility label. An item-level `symbol` overrides
the automatic icon; `showSymbol: false` hides it.

### Battery appearance

Battery displays text and state-dependent icons by default. Omitting its
configuration block behaves the same as an empty `{}` block. Add a `battery`
block to customize the appearance; use `showSymbol: false` for text only:

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

An item-level `symbol` overrides the dynamic symbol, while `showSymbol: false`
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

An `aerospace` item shows the focused Aerospace workspace name by default. It queries structured workspace data independently every two seconds, with a two-second timeout. Executables are located in PATH or the standard Homebrew prefixes. Missing installations display `Aerospace not installed`; failed, empty, malformed, or incompatible CLI output displays `Aerospace unavailable`. The provider uses `list-workspaces --all --json --format` with workspace focus, visibility, and AppKit monitor-index fields; the installed Aerospace version must support those fields.

```json
{
  "id": "aerospace",
  "type": "aerospace",
  "aerospace": {
    "scope": "display",
    "format": "list",
    "labels": {"1": "Code", "web": "Web"},
    "tints": {"focused": "#FFFFFF", "visible": "#88CCFF", "inactive": "#888888"}
  }
}
```

`aerospace.scope` is `"focused"` (default, across all monitors) or `"display"` (the workspaces on each bar's display). `format` is `"current"` (default) or `"list"` (read-only, with the focused workspace bold). In display scope, current mode shows that monitor's visible workspace, even when another monitor has focus. Monitor indexes are mapped to display UUIDs when querying; a display-layout change during the query invalidates that result.

`labels` maps actual workspace names to display labels. `showValue:false` shows only the symbol; `showSymbol:false` hides the symbol. Both default to `true`. `symbols.available` and `symbols.unavailable` override `rectangle.3.group` and `questionmark`, and accept SF Symbol names or custom glyphs with shared `symbols.font` and `.size`. The top-level `symbol` overrides both states. `tints.focused`, `.visible`, `.inactive`, and `.unavailable` customize state colors; focused takes precedence over visible. Unspecified colors inherit the item style.

Manual/event triggers request a fresh Aerospace query and capture its completed snapshot. Bursts coalesce and superseded queries cannot publish stale results. Background polling continues independently; interval refresh captures the latest polled snapshot. To reduce workspace-switch latency, an existing Aerospace workspace-change callback can invoke `sbar trigger <item-id>` with the bar's socket option. The item must have a manual or event `refresh` configuration. sbar does not modify Aerospace configuration.

A `yabai` item shows the focused Space's Yabai label, falling back to its Mission Control index when the label is absent or blank. It polls independently every two seconds and captures structured Space and display data.

```json
{
  "id": "yabai",
  "type": "yabai",
  "yabai": {
    "scope": "display",
    "format": "list",
    "includeFullscreen": false,
    "tints": {"focused": "#FFFFFF", "visible": "#88CCFF", "inactive": "#888888"}
  }
}
```

`yabai.scope` is `"focused"` (default, across displays) or `"display"` (each bar's display). `format` is `"current"` (default) or `"list"` (read-only, with the focused Space bold). Display scope shows that display's visible Space in current mode. Display indexes are mapped using Yabai's display UUIDs, so custom Yabai display ordering is supported.

`includeFullscreen` defaults to `true`. When disabled, lists omit native fullscreen Spaces without renumbering the remaining Mission Control indexes. An active fullscreen Space displays `Fullscreen` in current mode; lists retain other Spaces without highlighting the excluded Space. If the filtered list is empty, the value is `Fullscreen`. Labels come from Yabai and blank labels fall back to indexes; indexes may change when Spaces are added, removed, or reordered.

`showValue:false` shows only the symbol; `showSymbol:false` hides the symbol. Both default to `true`. `symbols.available` and `.unavailable` override `rectangle.3.group` and `questionmark`, with the same SF Symbol/custom glyph support and shared `symbols.font` and `.size` as Aerospace. A top-level `symbol` overrides both states. `tints.focused`, `.visible`, `.inactive`, and `.unavailable` customize colors; focused takes precedence over visible, and unspecified tints inherit the item style.

Manual/event triggers request fresh queries before capturing the result. Interval refresh captures the latest polled snapshot. Existing Yabai signals can invoke `sbar trigger <item-id>` for an item with manual/event refresh configured; sbar does not install signals or change Yabai configuration. Refresh bursts coalesce, cancelled queries cannot publish, and incomplete snapshots receive up to three attempts while retaining the previous value. Each CLI invocation has a two-second timeout; a snapshot queries displays, Spaces, then displays again to check the mapping. Polling does not overlap an in-flight refresh.

Missing installations display `Yabai not installed`; failed, malformed, or inconsistent reads display `Yabai unavailable` after retries. stdout is parsed separately from diagnostics. Executables are located in PATH or the standard Homebrew prefixes.

A `spaces` item shows native macOS Spaces without a window-manager integration. By default, every bar shows the focused Space's one-based position across displays, including fullscreen Spaces:

```json
{"id": "spaces", "type": "spaces"}
```

Set `spaces.scope` to `"display"` to show the Spaces belonging to each bar's display. When macOS shares Spaces across displays, bars use the shared Space list. `spaces.format` supports `"current"` (default), `"currentTotal"` (`2 / 4`), and `"list"` (all positions, with the active Space in bold). Lists are read-only.

```json
{
  "id": "spaces",
  "type": "spaces",
  "spaces": {
    "scope": "display",
    "format": "list",
    "labels": {"1": "Code", "2": "Web"},
    "tints": {"active": "#FFFFFF", "inactive": "#888888", "unavailable": "#FF6666"},
    "includeFullscreen": false
  }
}
```

Labels replace one-based positions within the selected scope after fullscreen filtering. Positions can change when Spaces are reordered, added, or removed; labels are not tied to persistent Space IDs. With `includeFullscreen:false`, an active fullscreen Space displays `Fullscreen` in current modes; a list shows the remaining desktop Spaces with none highlighted. If no desktop Spaces remain, it displays `Fullscreen`.

`spaces.showValue:false` displays only the symbol; `spaces.showSymbol:false` hides the symbol. Both default to `true`. `spaces.symbols.available` and `.unavailable` override the default `rectangle.3.group` and `questionmark` symbols. They accept SF Symbol names or custom glyphs with shared `spaces.symbols.font` and `.size`, like other providers. A top-level `symbol` overrides both states. `spaces.tints.active` colors the current value or active list entry; `.inactive` colors other list entries, and `.unavailable` colors an unavailable state. Unspecified tints inherit the item style.

The provider refreshes on Space switches, application activation, and display changes. Notification bursts coalesce, and incomplete transition snapshots receive bounded retries while retaining the previous snapshot. It uses private SkyLight APIs and shows `Spaces unavailable` when the requested Space or display cannot be read. Manual and event refresh modes capture the full snapshot, so each bar can render its own display from the same captured state.

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
