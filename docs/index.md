# Documentation

[Project README](../README.md)

Start with [getting started](getting-started.md), then use the guides and provider pages below.

## Guides

- [Configuration](configuration.md): config files, bar settings, items, and refresh policies.
- [Themes and item styling](styling.md): colors, fonts, padding, and backgrounds.
- [Text templates](text-templates.md): provider values and conditional labels.
- [Symbols](symbols.md): SF Symbols, font glyphs, and state icons.
- [Actions](actions.md): commands, URLs, and applications opened from items.
- [Groups, popups, and overflow](layout.md): child items and limited space.
- [Command line](cli.md): start, validate, query, reload, update, trigger, subscribe, and stop.
- [Development](development.md): build, test, and formatting commands.

## Providers

Each page covers the provider's configuration, defaults, refresh behavior, and limitations. Shared options are in [configuration](configuration.md#items), [styling](styling.md), and [symbols](symbols.md).

| Category | Providers |
| --- | --- |
| Desktop | [Date and time](providers/datetime.md), [frontmost application](providers/front-application.md) |
| Power and audio | [Battery](providers/battery.md), [volume](providers/volume.md), [audio devices](providers/audio-device.md) |
| Connectivity | [Mail](providers/mail.md), [Network](providers/network.md), [VPN](providers/vpn.md), [Bluetooth](providers/bluetooth.md) |
| System metrics | [CPU](providers/cpu.md), [memory](providers/memory.md), [disk](providers/disk.md), [throughput](providers/throughput.md) |
| Weather | [Open-Meteo](providers/weather.md) |
| Playback | [Media](providers/media.md) |
| Workspaces | [macOS Spaces](providers/spaces.md), [Aerospace](providers/aerospace.md), [Yabai](providers/yabai.md) |
| Custom data | [Shell commands](providers/command.md), [process plugins](providers/plugin.md) |

## Examples and schema

- [Everyday bar](../examples/everyday/README.md)
- [Floating bar](../examples/floating/README.md)
- [Configuration JSON Schema](../Sources/SbarCore/Resources/config.schema.json)
