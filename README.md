# StarkBar

A native macOS bar built with SwiftUI and a small AppKit window layer. Requires macOS 14 or later.

## Build

```sh
swift test
bash script/build_and_run.sh --build
```

The build script creates `dist/StarkBar.app`. Omit `--build` to build and launch it.

## Configuration

StarkBar reads `~/.config/starkbar/config.json` and reloads it when the file changes. Missing files use built-in defaults; invalid edits retain the last valid configuration and show the error in Settings.

In Settings, **Save Configuration** writes the currently loaded configuration, creating the directory if needed. Before replacing an existing file, it saves the exact previous contents to `config.json.bak`. There is one rotating backup, including when the previous file contains invalid JSON. If the backup cannot be written, the configuration is not replaced. External editor changes are reloaded but do not create backups.

Saving also writes `config.schema.json` beside the configuration and adds a `$schema` reference for compatible editors. **Reveal Configuration** shows the file in Finder. Saving writes the app's supported fields; unrecognized fields are only preserved in the backup.

A minimal configuration is:

```json
{
  "schemaVersion": 1,
  "bar": {},
  "items": {
    "right": [
      { "id": "clock", "type": "clock", "format": "HH:mm" }
    ]
  }
}
```

Bar settings default to `position: top`, `height: 32`, and `displays: all`. Positions are `top` or `bottom`; display choices are `main` (primary display) or `all`. Both positions use the screen's visible area alongside the system menu bar and Dock. Omitted item sections are empty. Item IDs must be nonblank and unique across all sections; cross-section uniqueness is checked by the app rather than the JSON Schema.

See [PLAN.md](PLAN.md) for implementation status and upcoming work.

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
        "type": "clock",
        "symbol": "clock",
        "format": "HH:mm",
        "style": { "tint": "#88C0D0", "background": "#FFFFFF18" }
      }
    ]
  }
}
```

Colors use `#RRGGBB` or `#RRGGBBAA` (alpha last). An omitted bar background uses the system material. An omitted item tint uses the system primary color; item backgrounds default to transparent. Use `#00000000` to clear an inherited background.

Item styles support `tint`, `background`, `fontSize` (8–72 points), `fontWeight` (`regular`, `medium`, `semibold`, `bold`), `horizontalPadding` (0–96), `verticalPadding` (0–48), and `cornerRadius` (0–48). Defaults are 13-point regular text with no item padding or corner radius. The theme's bar `horizontalPadding` and `itemSpacing` default to 10 points and accept 0–96. Oversized content stays clipped to its bar region; styling does not increase bar height. `symbol` applies to text, clock, and front-application items.

## Native items

`frontApplication`, `battery`, `volume`, `network`, and `wifi` use native change notifications. `cpu`, `memory`, `disk`, and `throughput` sample once every two seconds, shared across displays. `clock` and `date` share one clock. Memory reports active, wired, and compressed pages; disk reports free space on the home volume. Throughput totals non-loopback interfaces, so tunnels may contribute additional traffic. Fixed-volume outputs display that status rather than a fabricated percentage.

`media` listens for Music and Spotify playback notifications. It waits for the next notification after startup and does not query or control other players. Wi-Fi reports connection state, not the location-protected SSID.

## Actions, commands, groups, and overflow

Items accept `primaryAction` and `secondaryAction` objects with `kind` (`command`, `url`, or `application`) and `value`. Primary actions run on click; secondary actions appear in the context menu. URL actions allow HTTP, HTTPS, and mailto. Application values are bundle IDs or paths; `${NAME}` and `~` expand in URL/application paths. Shell actions use `/bin/sh -c` and inherit the environment.

A `command` item requires `command: {"script":"date", "interval":10, "timeout":5}`. Omit `interval` to run once; an optional `event` names a runtime trigger. Commands have a 64 KB combined output limit, a default five-second timeout, and terminate their process group on timeout, cancellation, or completion.

`group` items render `children` inline. `popup` items show `children` when clicked; any item can also have a `popup` text string. Groups nest up to eight levels. Disabling a group disables its child providers.

Each region measures its items and moves low-priority items into an overflow popover when space runs out. Larger `priority` values remain visible longer; equal priorities hide from the end. The center reserves one third of the bar when populated. Bar content stays clipped within its own region.

## Runtime control

The bundle includes `Contents/MacOS/barctl` (also built by SwiftPM). It connects to `~/.config/starkbar/control.sock`; use `--socket <path>` for another configuration directory.

```sh
barctl query
barctl reload
barctl set clock enabled false
barctl set clock style '{"tint":"#88C0D0"}'
barctl trigger refresh '{"source":"manual"}'
barctl subscribe
```

`set` changes in-memory configuration only. Supported properties are `label`, `symbol`, `enabled`, `priority`, `format`, `style`, and `popup`; Settings Save persists the current state. Reload discards transient changes. `subscribe` streams JSON lines for configuration changes, provider values, and triggers. Trigger payloads are retained in events; matching command items rerun. Clients must belong to the same user. Slow subscribers are disconnected, and a lock prevents multiple instances from owning the same socket.

## Settings editor

Settings keeps a draft separate from the running configuration. Drag top-level items onto another row to insert before it, or onto a section's Add item button to append. Context menus offer cross-section moves and deletion. Select an item for style/action controls; advanced item JSON edits nested children and less common options. The Theme tab edits shared defaults. Preview uses current provider snapshots and cannot execute click actions.

Save validates and persists the draft. Reload discards it. Import validates a JSON file into the draft; Export writes the draft to a chosen file. If live configuration changes while a draft is dirty, Settings shows a conflict notice. Invalid drafts remain editable while the preview retains the baseline configuration. Diagnostics lists recent runtime events and action failures.
