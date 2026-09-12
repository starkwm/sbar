# Volume

[Documentation index](../index.md#providers)

A `volume` item follows native output volume and mute change notifications.

Volume displays text and a state-dependent icon by default. An omitted `volume` block
behaves the same as `{}`. Customize it using grouped symbols and tints:

```json
{
  "id": "volume",
  "type": "volume",
  "volume": {
    "symbols": {
      "levels": [
        "speaker.fill",
        "speaker.wave.1.fill",
        "speaker.wave.2.fill",
        "speaker.wave.3.fill"
      ],
      "muted": "speaker.slash.fill"
    },
    "tints": {
      "muted": "#FF6655"
    }
  },
  "text": ""
}
```

`symbols.levels` accepts exactly four symbols: zero (0%), low (1–33%), medium (34–66%),
and high (67–100%). The example shows the default level and mute symbols. Zero volume
and mute are separate states. `symbols.fixed` defaults to `speaker.wave.3.fill` for outputs
without a readable volume; `symbols.unavailable` defaults to `speaker.slash` when no output
is available. No output takes precedence over mute, which takes precedence over volume level.

Glyphs inherit `symbols.font` and optional `symbols.size`, with per-symbol overrides,
as described in [Symbols](../symbols.md). `tints.muted`, `tints.fixed`, and `tints.unavailable` override
the normal item/theme tint in their respective states.

`showSymbol` defaults to `true`. Default text is `Volume N%`, `Muted`,
`Fixed volume`, or `No output`. Top-level `text: ""` hides the label while retaining
its accessibility description. An item-level `symbol` overrides
the automatic icon; `showSymbol: false` hides it.

Volume templates expose `status` as `available`, `muted`, `fixed`, or `unavailable`. Use [state conditions](../text-templates.md#state-specific-labels) to customise their labels.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
