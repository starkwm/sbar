# Network

[Documentation index](../index.md#providers)

A `network` item follows native connection change notifications. It reports connection state without reading the location-protected Wi-Fi SSID.

Configure connection symbols under `network` and label visibility with top-level `text`:

```json
{
  "id": "network",
  "type": "network",
  "network": {
    "symbols": {
      "wifi": "wifi",
      "ethernet": "cable.connector",
      "cellular": "antenna.radiowaves.left.and.right",
      "other": "network",
      "offline": "network.slash"
    }
  },
  "text": ""
}
```

These are the default symbols, including when the `network` block is omitted.
Each value accepts an SF Symbol name or a font glyph object. Glyphs inherit
`symbols.font` and optional `symbols.size`, with per-symbol overrides.
An item-level `symbol` remains a fixed override; `network.showSymbol: false`
hides the icon, including an override.

Set top-level `text` to an empty string to show only the symbol while retaining
the connection status for accessibility.

The default text is `Wi-Fi`, `Connected` (Ethernet, cellular, or other), or `Offline`.
An unsatisfied path is offline; otherwise Wi-Fi takes precedence over Ethernet,
then cellular, then other when macOS reports multiple interface types.
This describes the active path, not all connected adapters, and does not identify VPNs.
Use top-level [text conditions](../text-templates.md#state-specific-labels) such as
`{{#status=wifi}}Wi-Fi connected{{/status}}{{^status=wifi}}{{value}}{{/status}}` to
customize state labels. `network.tints` uses the same five state keys for colors. `showSymbol` defaults to `true`;
`hideWhenDisconnected` defaults to `false` and hides the item in its offline state.
Refresh policies capture the connection state, text, symbol, color, and visibility together.

To monitor Wi-Fi specifically:

```json
{
  "id": "wifi",
  "type": "network",
  "network": {
    "interface": "wifi",
    "hideWhenDisconnected": true,
    "tints": {
      "wifi": "#66CC88",
      "offline": "#FF6655"
    }
  },
  "text": ""
}
```

`interface` accepts `wifi`, `ethernet`, `cellular`, or `other`. Omit it to follow
the active connection. A different active interface is presented as `offline`
for the filtered item. Wi-Fi filtering defaults to `Wi-Fi connected` /
`Wi-Fi disconnected` and `wifi` / `wifi.slash`. It describes the active path,
not radio power, association, SSID, or signal strength.

Migration: replace `"type": "wifi"` with `"type": "network"`, rename its `wifi`
block to `network`, and add `"interface": "wifi"`. Rename `connected` /
`disconnected` symbol and tint keys to `wifi` / `offline`; move
old label overrides into top-level `text` conditions on `status=wifi` / `status=offline`.
Replace old network text visibility settings with top-level `text: ""` to hide the label. Set `network.showSymbol: false` to retain a text-only item.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
