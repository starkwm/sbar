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

This generates `Sources/Sbar/Version.swift` from `Sources/Sbar/Version.swift.tmpl`. Commit the generated file with the release changes, then rebuild to update `sbar --version`.

## Spaces transitions

`BarSpace` loads private SkyLight functions at runtime and keeps the bar panels in a shared Space during desktop transitions. The implementation follows [SketchyBar](https://github.com/FelixKratz/SketchyBar/blob/master/src/window.c).

`BarCoordinator` attaches panels after AppKit positions and orders them. At shutdown, it closes the panels before destroying their Space. If the APIs are missing or Space creation returns no ID, sbar logs a warning and uses AppKit's collection behavior. The level, visibility, and attachment calls are asynchronous and return no status on macOS 26.

After changing window management, check keyboard and trackpad Space transitions, full-screen apps, multiple displays, configuration reloads, and sleep/wake on a running bar. Unit tests cover Space ownership, cleanup, and failure recovery. They cannot verify transition animations or compatibility with future macOS versions.
