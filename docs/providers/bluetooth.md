# Bluetooth

[Documentation index](../index.md#providers)

A `bluetooth` item shows Bluetooth power state and connected device names:

```json
{
  "id": "bluetooth",
  "type": "bluetooth",
  "bluetooth": {
    "hideWhenDisconnected": true,
    "tints": {
      "connected": "#8AADF4",
      "unauthorized": "#ED8796"
    }
  }
}
```

With connected devices, the default text lists their names and status, such as
`Keyboard connected, Mouse connected`, sorted by name. Otherwise it shows
`Bluetooth on` or `Bluetooth off`. Denied or restricted access shows
`Bluetooth access denied`; missing hardware, read failures, or a resetting
controller show `Bluetooth unavailable`.

Use top-level `text: "Bluetooth {{status}}"` for a status label, include `{{names}}`
for connected device names, or use `text: ""` for an icon alone. `showSymbol`
defaults to `true`. Accessibility retains device names. Set `hideWhenDisconnected`
to `true` to hide the item when Bluetooth is off or has no connected devices.

`bluetooth.labels`, `bluetooth.tints`, and `bluetooth.symbols` accept `on`, `off`,
`connected`, `unauthorized`, and `unavailable`. Labels replace the status text.
The default symbols are `antenna.radiowaves.left.and.right` for on and connected,
`antenna.radiowaves.left.and.right.slash` for off, and `exclamationmark.triangle`
for access errors or unavailable data. Custom symbols and font glyphs work as
with other providers; a top-level item `symbol` overrides state symbols.

Monitoring starts only when a Bluetooth item is active. macOS may request
Bluetooth access at that point. The executable embeds the required usage
description. If access is denied, allow it in System Settings > Privacy &
Security > Bluetooth and restart sbar. Custom app bundles must also include
`NSBluetoothAlwaysUsageDescription` in their Info.plist. The provider waits for
the initial permission and power state before capturing refresh snapshots.

Power and authorization use Core Bluetooth. Device names and connections use
IOBluetooth's paired-device list and connection notifications. This covers
connected devices exposed by IOBluetooth, including new connections observed
while the provider is running. It does not scan, pair, connect, disconnect, or
change Bluetooth power. Devices exposed only through Bluetooth Low Energy
services may be absent. Device battery levels are not included.

Items share one monitor across displays. Device and power changes update event
items; interval and manual items capture snapshots as with other native
providers. Unavailable reads retry every two seconds.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
