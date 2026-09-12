# Symbols

[Documentation index](index.md)

Set an item's `symbolPosition` to `"left"` or `"right"` to place its symbol on that side of its text:

```json
{
  "id": "battery",
  "type": "battery",
  "symbolPosition": "right"
}
```

The default is `"left"`; omitting the setting or using `null` keeps that appearance.
Placement applies to SF Symbols, custom font glyphs, provider state symbols, and
[frontmost application icons](providers/front-application.md). For segmented providers such
as throughput, each symbol moves beside its own text while the segments keep their order.
Download still precedes upload when both symbols are on the right.
Set placement on each item, including children inside groups and popovers; groups do not pass it to their children.

Every `symbol`, including battery and network state symbols, accepts either an SF Symbol name
or a glyph object. Install the font on your Mac first and use its font name:

```json
{
  "id": "wifi",
  "type": "network",
  "network": {
    "interface": "wifi",
    "symbols": {
      "font": "Symbols Nerd Font Mono",
      "wifi": {
        "glyph": ""
      },
      "offline": "wifi.slash"
    }
  },
  "text": ""
}
```

`glyph` is literal text (JSON Unicode escapes work too), `font` selects the installed font,
and optional `size` accepts 8–72 points. Without `size`, glyphs use the resolved item/theme
font size. Only the symbol uses the custom font; item text retains its normal font. Missing
fonts or glyphs use macOS font fallback, which may display a missing-character box.
SF Symbol strings continue to work, and can be mixed with glyph objects.

Battery `symbols.levels` accepts exactly five symbols, ordered 0%, 25%, 50%, 75%, 100%:

```json
{
  "id": "battery",
  "type": "battery",
  "battery": {
    "symbols": {
      "font": "Symbols Nerd Font Mono",
      "levels": [
        { "glyph": "\uf244" },
        { "glyph": "\uf243" },
        { "glyph": "\uf242" },
        { "glyph": "\uf241" },
        { "glyph": "\uf240" }
      ],
      "charging": { "glyph": "\uf0e7" }
    }
  }
}
```

Within `battery.symbols`, `cpu.symbols`, `disk.symbols`, `media.symbols`, `memory.symbols`, `network.symbols`, `throughput.symbols`, `volume.symbols`, `vpn.symbols`, `bluetooth.symbols`, and `audioDevice.symbols`, glyphs inherit `font` and optional `size` (8–72 points).
Each glyph can override either value. A font must be provided locally or inherited;
without either size, the resolved item/theme font size is used. Strings remain SF Symbol
names and do not inherit glyph font settings. Omitted state symbols use the built-in defaults.

An item-level `symbol` overrides all state symbols;
`showSymbol: false` hides the symbol regardless of these settings.

The transient [`set` command](cli.md#update-items) also accepts a glyph object for the item-level `symbol`.

See [item styling](styling.md) for text and SF Symbol weights, and each [provider's documentation](index.md#providers) for its state symbols.
