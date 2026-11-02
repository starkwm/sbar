# Getting started

[Documentation index](index.md)

## Requirements

- macOS 26 or later
- Xcode 26 or later when building from source, with Swift 6.2

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

Use `make release` for an optimized build in `.build/release`. The bar remains a standalone executable. Calendar and Reminders additionally use the background `Sbar EventKit.app` helper, which `make build` and `make release` package beside it. Keep the executable and helper together when installing; a symlink to the executable on your `PATH` is supported. Other providers do not require this helper. See [EventKit helper packaging](development.md#eventkit-helper) for the directory layout and signing.

A source build is not installed as a background service automatically. To run at login, create a Launch Agent that starts the executable using its absolute path.

## Configure the bar

Without a configuration file, sbar shows the active application, a divider, and a clock. Create `~/.config/sbar/config.json` to choose your own items. Changes reload automatically; invalid edits retain the last valid configuration.

Follow the [configuration guide](configuration.md) for a minimal example and validation, then choose your [providers](index.md#providers). The [Everyday bar](../examples/everyday/README.md) includes app shortcuts, system status popovers, and volume controls. The [floating bar](../examples/floating/README.md) uses inset edges and rounded corners.

Use `sbar stop` to stop the running bar. See the [CLI guide](cli.md) for custom configuration paths and control sockets.
