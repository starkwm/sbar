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

`glyph` is literal text and also accepts JSON Unicode escapes. `font` selects the installed font,
and optional `size` accepts 8 to 72 points. Without `size`, glyphs use the resolved item/theme
font size. Only the symbol uses the custom font; item text retains its normal font. Missing
fonts or glyphs use macOS font fallback, which may display a missing-character box.
SF Symbol strings continue to work, and can be mixed with glyph objects.

Battery `symbols.levels` and optional `symbols.chargingLevels` each accept exactly five symbols, ordered 0%, 25%, 50%, 75%, 100%:

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

Every provider `symbols` block supports shared `font` and optional `size` from 8 to 72 points, including workspace, command, and plugin symbols.
Each glyph can override either value. A font must be provided locally or inherited;
without either size, the resolved item/theme font size is used. Strings remain SF Symbol
names and do not inherit glyph font settings. Omitted state symbols use the built-in defaults.

An item-level `symbol` overrides provider state symbols. Set `showSymbol: false` inside the provider block to hide them. Frontmost application icons have their own [`showIcon` setting](providers/front-application.md) and take precedence over the item symbol.

The transient [`set` command](cli.md#update-items) also accepts a glyph object for the item-level `symbol`.

See [item styling](styling.md) for text and SF Symbol weights, and each [provider's documentation](index.md#providers) for its state symbols.

## Workspace name icons

Entries in [`spaces.names`](providers/spaces.md#name-overrides) can replace individual workspace labels with icons. Use `{ "symbol": "globe" }` for an SF Symbol or `{ "symbol": { "glyph": "\uf121", "font": "Symbols Nerd Font Mono" } }` for a Nerd Font glyph. A plain string such as `"globe"` displays as text.

Name icons appear in the default current label and at `{{name}}` or `{{value}}` in workspace templates. They keep each entry's tint and active highlighting. `symbolPosition` does not move them away from the template insertion point.

`spaces.showSymbol` and the item's top-level `symbol` control the separate provider icon. Name icons remain visible when `spaces.showSymbol` is `false`; an empty `text` hides them with the rest of the label. Each glyph object in `spaces.names` needs its own `font` and can set `size`. It does not inherit the font from `spaces.symbols`.
