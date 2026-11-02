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

## EventKit helper

`make build` and `make release` build both executables and package the EventKit executable as a background app:

```text
.build/debug/
  sbar
  Sbar EventKit.app/
    Contents/Info.plist
    Contents/MacOS/sbar-eventkit
```

Keep `Sbar EventKit.app` beside the real `sbar` executable when installing. The CLI resolves symlinks before locating the helper, so a symlink in a Homebrew `bin` directory can point to an executable and helper installed together in `libexec`. Copying only `sbar` still supports other providers, but Calendar and Reminders will be unavailable. Plain `swift build` does not assemble the app bundle; use `make build` for live testing.

The packaging script signs the helper ad hoc by default. Distributors can set `CODE_SIGN_IDENTITY` to a signing identity available in their keychain. Preserve the complete signed bundle when installing. Development rebuilds may require renewed permission; stable release signing is needed for consistent identity across upgrades.

The bar and `sbar reminders lists` launch the helper through `NSWorkspace`, rather than directly executing its binary as a terminal child. The helper has bundle ID `dev.starkwm.sbar.eventkit`, no Dock icon or window, and its own Calendar and Reminders usage descriptions. Permission prompts should name **Sbar EventKit**, independently of the terminal. Existing permissions granted to Terminal, Rex or the old sbar process are not transferred. This does not bypass denial, system restrictions or the requirement for a logged-in graphical macOS session.

Only the helper accesses EventKit. It handles list discovery and snapshot reads over a local socket in an owner-only directory, with an owner-only socket. Messages carry value records; no reminder content is written to disk. The socket identity includes the bundle path and executable build hash, keeping development/release installations and rebuilt helpers separate. A real ping checks readiness, not just socket-file existence. Change notifications contain no calendar or reminder data.

Requests have unique IDs, explicit cancellation and a five-minute lifetime including permission decisions. Completed results are discarded when collected. The helper allows at most 32 outstanding requests and exits after roughly two idle minutes when none remain. Calendar and Reminders retain their minute polling and change-driven collection. The next request relaunches an exited helper. Removing the last provider stops bar-side collection immediately; the helper then exits after its idle grace period. The helper's socket protocol is internal, not a supported public CLI.

Automated tests exercise injected launchers/readers and temporary socket servers. They never launch the helper, request Calendar/Reminders permission or read live data. Before releasing, manually test both list discovery and the bar from Terminal and Rex. Verify the prompt identifies Sbar EventKit, edits propagate, denial/regrant recovers, and a fresh helper starts after its idle exit. Validate packaged release artifacts as well as development builds. Never test by running `Contents/MacOS/sbar-eventkit` directly, because that restores terminal-child permission attribution.
