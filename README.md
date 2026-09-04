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
