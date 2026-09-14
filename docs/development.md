# Development

[Documentation index](index.md)

Run these commands from the repository root:

```sh
make build    # Debug build
make release  # Optimized build
make test     # Run tests
make format   # Format Swift sources
make lint     # Check Swift formatting
make clean    # Remove build products
```

See [getting started](getting-started.md) for build requirements, output locations, and running the bar.

## Update the version

```sh
make bump_version NEW_VERSION=v0.0.1
```

This generates `Sources/Sbar/Version.swift` from `Sources/Sbar/Version.swift.tmpl`, matching swm's version workflow. Commit the generated file with the release changes, then rebuild to update `sbar --version`.

## Spaces transitions

`BarSpace` uses dynamically loaded SkyLight APIs to keep the bar panels in a shared Space that stays visible during desktop transitions. This follows [SketchyBar's approach](https://github.com/FelixKratz/SketchyBar/blob/master/src/window.c). The coordinator attaches panels after AppKit positions and orders them, and destroys the Space after closing the panels at shutdown. If the APIs are missing or Space creation returns no ID, sbar logs a warning and retains its AppKit collection behavior. The level, visibility, and attachment calls are asynchronous and return no status on macOS 26.

These APIs are private and may change with macOS updates. After changing window management, check keyboard and trackpad Space transitions, full-screen apps, multiple displays, configuration reloads, and sleep/wake on a running bar. Unit tests cover Space ownership, cleanup, and failure recovery, but cannot verify the transition animation.
