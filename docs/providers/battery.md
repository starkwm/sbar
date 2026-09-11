# Battery

[Documentation index](../index.md#providers)

A `battery` item follows native battery and power-state change notifications.

Battery displays text and state-dependent icons by default. Omitting its
configuration block behaves the same as an empty `{}` block. Add a `battery`
block to customize the appearance; use `showSymbol: false` for text only:

```json
{
  "id": "battery",
  "type": "battery",
  "battery": {
    "showPercentage": false,
    "lowThreshold": 20,
    "tints": {
      "low": "#FF6655",
      "charging": "#66CC88"
    },
    "symbols": { "pluggedIn": "powerplug" }
  }
}
```

Battery settings: `showPercentage` and `showSymbol` default to `true`. The icon follows charge
level in 25% steps, uses `symbols.charging` (default `battery.100percent.bolt`) while charging,
and `symbols.pluggedIn` (default `powerplug`) on AC power without charging. `lowThreshold`
defaults to 20 and accepts 0–100, inclusive. `tints.low` applies at or below that threshold
while running on battery; `tints.charging` and `tints.pluggedIn` apply to their respective power
states. A computer without a battery displays `AC power` and the plugged-in icon.

An item-level `symbol` overrides the dynamic symbol, while `showSymbol: false`
hides it. State colors override `style.tint` when supplied; otherwise the normal item/theme tint
applies. Colors accept `#RRGGBB` or `#RRGGBBAA`. Icon-only widgets retain an accessibility label.
Refresh policies capture text, symbols, colors, and visibility together. Edit these settings in
the configuration file and reload; the `set` command does not accept the widget blocks.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
