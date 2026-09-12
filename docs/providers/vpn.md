# VPN

[Documentation index](../index.md#providers)

A `vpn` item shows the names and status of VPN services registered with macOS:

```json
{
  "id": "vpn",
  "type": "vpn",
  "vpn": {
    "hideWhenDisconnected": true,
    "tints": {
      "connected": "#A6DA95",
      "connecting": "#EED49F",
      "unavailable": "#ED8796"
    }
  }
}
```

The default text includes every connected or transitioning service, such as
`Tailscale connected, Work connecting`, sorted by name. Disconnected services
are omitted from that list. With none active, the item shows `VPN disconnected`.
`hideWhenDisconnected` defaults to `false` and hides only a confirmed disconnected
state. Failed reads show `VPN unavailable`, or the affected service's name and
`unavailable`, and remain visible.

Use top-level `text: "VPN {{status}}"` for an aggregate status, include `{{names}}`
for service names, or use `text: ""` for an icon alone. `showSymbol` defaults to
`true`. Accessibility retains service names and statuses.

`vpn.labels`, `vpn.tints`, and `vpn.symbols` accept `connecting`, `connected`,
`disconnecting`, `disconnected`, and `unavailable` keys. Labels replace the status
word after each name. Symbols default to `lock.shield.fill` when connected,
`arrow.triangle.2.circlepath` during transitions, `lock.shield` when disconnected,
and `exclamationmark.shield` when unavailable. Symbols support custom glyphs with
shared `font` and `size`, and a top-level item `symbol` overrides them.

With multiple services, the overall symbol and tint use the first present state
in this order: unavailable, connected, connecting, disconnecting, disconnected.
Known active names remain visible if another service cannot be read.

The provider uses native SystemConfiguration service and connection notifications,
shared across items and displays. It retries unavailable reads every two seconds.
Event, interval, and manual refresh modes use the same snapshot behavior as other
native providers. It detects registered Network Extension, IPSec, and L2TP VPN
services. Standalone tunnels that do not register a macOS service are outside its
coverage. A connected state reports the VPN service's status, not whether all
traffic uses that VPN or whether its remote network is reachable.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
