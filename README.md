# sbar

Stark Bar for macOS.

`sbar` is a configurable status bar with native system information, shell commands, and process plugins. Arrange items across the left, center, and right of each display, and control the running bar from the command line.

## Quick start

Requires macOS 26 or later. Building from source requires Xcode 26 or later with Swift 6.2.

```sh
git clone https://github.com/starkwm/bar.git
cd bar
make build
.build/debug/sbar
```

Without a configuration file, sbar shows the active application, a divider, and a clock. Create `~/.config/starkbar/config.json` to choose your own items. Changes reload automatically.

See [getting started](docs/getting-started.md) for release builds and setup, or the [configuration guide](docs/configuration.md) for a minimal config.

## Documentation

The [documentation index](docs/index.md) links to all guides and provider references.

- [Providers](docs/index.md#providers)
- [Themes and styling](docs/styling.md)
- [Command line](docs/cli.md)
- [Development](docs/development.md)

## Examples

- [Demo configuration](examples/demo/README.md) with native metrics, popups, actions, commands, and a streaming plugin.
- [Floating bar](examples/floating/README.md) with inset edges and rounded corners.
