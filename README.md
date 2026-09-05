# sbar

A native macOS bar built with SwiftUI and a small AppKit window layer. Requires macOS 14 or later.

## Build

```sh
make
make test
make release
```

The executable is `.build/debug/sbar` (or `.build/release/sbar` for release builds). Run `sbar` or `sbar start` to start the bar. Use `sbar --help` for commands. Keep the SwiftPM resource bundle alongside the executable when copying build outputs.

`Sources/Sbar` contains the command-line entry point and commands. `Sources/SbarCore` contains the app, bar runtime, providers, configuration, and IPC. Client commands run without starting the bar. There is no Settings window or menu bar icon; control the app through the executable.

The Makefile follows the `skbd` and `swm` workflow: `make` builds debug executables, `make release` builds optimized executables, `make format` formats Swift sources, `make lint` checks formatting, and `make clean` removes SwiftPM build products.

## Configuration

Edit `~/.config/starkbar/config.json` in your preferred editor. sbar reloads it when the file changes. Missing files use built-in defaults; invalid edits retain the last valid configuration. Inspect errors with `sbar query --diagnostics`.

Run `sbar validate` (or `sbar validate --config /path/to/config.json`) to check a file without starting the bar. Invalid or missing files produce an error and a nonzero exit status. Validation never writes the file. Use `sbar start --config /path/to/config.json` to run with another configuration.

The config file is the only persistent configuration source. sbar never saves, rewrites, or backs it up. For editor completion, copy [config.schema.json](Sources/SbarCore/Resources/config.schema.json) beside your configuration and add `"$schema": "config.schema.json"` to the root object.

For a larger example with native metrics, popups, actions, commands, and a streaming plugin, see the [demo configuration](examples/demo/README.md).

A minimal configuration is:

```json
{
  "schemaVersion": 2,
  "bar": {},
  "items": {
    "right": [
      { "id": "clock", "type": "clock", "format": "HH:mm" }
    ]
  }
}
```

Bar settings default to `position: top`, `height: 32`, and `displays: all`. Positions are `top` or `bottom`; display choices are `main` (primary display), `all`, or `selected` with a `displayIDs` array. `sbar query --displays` lists connected display IDs, names, and the primary display. `windowLevel` accepts `floating`, `statusBar` (default), or `screenSaver`. Optional `mousePassThrough:true` lets empty regions pass mouse events to windows beneath the bar. Top placement uses the physical screen edge, sharing the system menu-bar area; bottom placement respects the Dock's visible work area. On notched displays, items avoid the cutout and the center section sits immediately to its right. Omitted item sections are empty. Item IDs must be nonblank and unique across all sections; cross-section uniqueness is checked by the app rather than the JSON Schema.

See [PLAN.md](PLAN.md) for implementation status and upcoming work.

Version-1 files migrate to version 2 in memory: legacy command intervals/events become item refresh policies, including inside groups. Loading never rewrites the source file; update it manually to persist the version-2 format. Future schema versions are rejected.

Start with an alternate file using `sbar --config /path/config.json`. Its control socket lives beside the chosen file.

`refresh` accepts `mode: event`, `interval`, or `manual`, with `seconds` required for intervals and an optional named `event`. Native event mode follows provider changes; interval/manual modes snapshot shared provider values. Triggering the item ID or its event captures a fresh snapshot. Underlying metric sampling remains shared at two-second resolution. Plugins retain their own streaming cadence and receive all runtime triggers.

## Themes and item styling

The optional top-level `theme` sets bar appearance and default item styling. Each item's `style` overrides individual theme fields. Omitted or null fields inherit; explicit zero padding and transparent colors override inherited values.

```json
{
  "schemaVersion": 2,
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

A `command` item requires `command: {"script":"date", "timeout":5}`. Add `refresh: {"mode":"interval", "seconds":10, "event":"refresh"}` to rerun periodically or on that trigger. Without a refresh interval, it runs once at startup and when triggered by its ID. Commands have a 64 KB combined output limit, a default five-second timeout, and terminate their process group on timeout, cancellation, or completion.

`group` items render `children` inline. `popup` items show `children` when clicked; any item can also have a `popup` text string. Groups nest up to eight levels. Disabling a group disables its child providers.

Each region measures its items, allows flexible text to compress, and moves low-priority items into an overflow popover when space runs out. Larger `priority` values remain visible longer; equal priorities hide from the end. On displays without a notch, the center reserves one third of the bar when populated. Beside a notch, the center and right sections share the usable right-hand area. Bar content stays clipped within its own region.

## Runtime control

Client commands (`query`, `reload`, `set`, `trigger`, `subscribe`, and `stop`) connect to `~/.config/starkbar/control.sock`; use `sbar query --socket <path>` for another configuration directory. These commands replace the former `sbarctl` executable.

```sh
sbar query
sbar query --diagnostics
sbar query --displays
sbar reload
sbar set clock enabled false
sbar set clock style '{"tint":"#88C0D0"}'
sbar trigger refresh '{"source":"manual"}'
sbar subscribe
sbar stop
```

`set` changes in-memory configuration only. Supported properties are `label`, `symbol`, `enabled`, `priority`, `format`, `style`, and `popup`. Edit the config file to make changes persistent. Reload or restart discards transient changes. `subscribe` streams JSON lines for configuration changes, provider values, and triggers. Trigger payloads are retained in events; matching command items rerun. Clients must belong to the same user. Slow subscribers are disconnected, and a lock prevents multiple instances from owning the same socket.

`query` returns the running configuration. `query --diagnostics` returns the configuration path, current configuration error, last action error, and up to 100 recent runtime events. `query --displays` returns connected display IDs and names. The two selectors are mutually exclusive.

`stop` acknowledges the request, then shuts down the bar, stops providers and child processes, closes panels, and removes the control socket. Use `--socket` to target an instance started with a custom configuration directory.

## Process plugins and workspaces

A `plugin` item uses `plugin: {"executable":"/absolute/path/to/provider", "arguments":[], "restart":true}`. `${NAME}` and `~` expand in the executable path. The provider receives newline-delimited JSON on stdin: `{"version":1,"event":"start"}` initially, then runtime trigger events with an optional `value`. It emits `{"text":"display text"}` lines on stdout. stderr is discarded. Flush stdout after each update.

Each output line is limited to 64 KB and displayed text to 4,096 characters. Bursts coalesce to the latest value in each read. The input mailbox holds up to 32 events and drops new events if full. Invalid output stops that process; automatic restarts back off from one to 30 seconds. Set `restart:false` for one-shot providers. Removing/disabling the item or shutting down terminates the process group.

`aerospace` and `yabai` items show the focused workspace, using [AeroSpace's focused-workspace query](https://nikitabobko.github.io/AeroSpace/commands#list-workspaces) and [yabai's space query](https://github.com/asmvik/yabai/wiki/Commands#querying-information). Executables are located in PATH or the standard Homebrew prefixes. Queries run every two seconds with a two-second timeout; missing or unavailable integrations show a status message. No adapter changes window-manager configuration.

The app pauses providers and commands during sleep and restarts them after wake. Panels follow screen and Space changes. See [manual validation](docs/manual-validation.md) for the remaining live checks; automated tests do not establish hardware or desktop behavior.
