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

## Permissions in a standalone executable

sbar ships as one executable. Calendar and Reminders use EventKit directly in
the sbar process, with their usage descriptions embedded in the executable's
Info.plist alongside the Bluetooth and Mail descriptions. No helper app is
required or launched.

macOS can attribute a command-line program's permission requests to the app
that launched it. Embedded usage descriptions do not guarantee the same
permission behavior in every terminal. During Reminders testing, discovery
succeeded in Terminal.app but was denied from Rex because macOS attributed
access to Rex Server, which lacked a required Reminders usage description.
See Apple's explanation of [process responsibility](https://developer.apple.com/forums/thread/125438).

If access is denied, check System Settings > Privacy & Security > Reminders
or Calendars for the application named by macOS. If the terminal cannot
request access, try Terminal.app. A grant there does not guarantee access
from another terminal. sbar does not bypass denied permission or modify the
launching application's metadata.

Builds and automated tests do not verify live permission behavior. Manually
test discovery and the bar from the terminal you intend to use, including
denial and regrant. Validation and CLI help do not request EventKit access.

## Update the version

```sh
make bump_version NEW_VERSION=v0.0.1
```

This generates `Sources/Sbar/Version.swift` from `Sources/Sbar/Version.swift.tmpl`. Commit the generated file with the release changes, then rebuild to update `sbar --version`.

## Spaces transitions

`BarSpace` loads private SkyLight functions at runtime and keeps the bar panels in a shared Space during desktop transitions. The implementation follows [SketchyBar](https://github.com/FelixKratz/SketchyBar/blob/master/src/window.c).

`BarCoordinator` attaches panels after AppKit positions and orders them. At shutdown, it closes the panels before destroying their Space. If the APIs are missing or Space creation returns no ID, sbar logs a warning and uses AppKit's collection behavior. The level, visibility, and attachment calls are asynchronous and return no status on macOS 26.

After changing window management, check keyboard and trackpad Space transitions, full-screen apps, multiple displays, configuration reloads, and sleep/wake on a running bar. Unit tests cover Space ownership, cleanup, and failure recovery. They cannot verify transition animations or compatibility with future macOS versions.
