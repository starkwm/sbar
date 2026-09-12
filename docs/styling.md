# Themes and item styling

[Documentation index](index.md)

The optional top-level `theme` sets bar appearance and default item styling. Each item's `style` overrides individual theme fields. Omitted or null fields inherit; explicit zero padding and transparent colors override inherited values.

```json
{
  "schemaVersion": 1,
  "bar": {},
  "theme": {
    "background": "#18202EEE",
    "horizontalPadding": 12,
    "itemSpacing": 8,
    "itemStyle": {
      "tint": "#E5E9F0",
      "fontSize": 13,
      "fontWeight": "medium",
      "horizontalPadding": 6,
      "verticalPadding": 2,
      "cornerRadius": 4
    }
  },
  "items": {
    "right": [
      {
        "id": "clock",
        "type": "datetime",
        "symbol": "clock",
        "format": "HH:mm",
        "style": { "tint": "#88C0D0", "background": "#FFFFFF18" }
      }
    ]
  }
}
```

Colors use `#RRGGBB` or `#RRGGBBAA` (alpha last). An omitted bar background uses the system material. An omitted item tint uses the system primary color; item backgrounds default to transparent. Use `#00000000` to clear an inherited background.

Item styles support `tint`, `background`, `fontSize` (8–72 points), `fontWeight` (`regular`, `medium`, `semibold`, `bold`), `horizontalPadding` (0–96), `verticalPadding` (0–48), and `cornerRadius` (0–48). Use `symbolFontWeight` (the same weight values) to override SF Symbol weight independently of text, either in `theme.itemStyle` or an item's `style`. For example, `"style": {"symbolFontWeight": "bold"}`. Item values override the theme; when neither sets it, symbols inherit the resolved text weight. This also applies to battery and network state symbols; font glyphs keep their custom font. Defaults are 13-point regular text with no item padding or corner radius. The theme's bar `horizontalPadding` and `itemSpacing` default to 10 points and accept 0–96. Oversized content stays clipped to its bar region; styling does not increase bar height.

Set `bar.shadow` to `true` for a raised appearance. Inset or rounded bars use the native window shadow; square bars spanning the display width use a soft edge shadow without an outline. See [bar settings](configuration.md#bar-settings) for height, margins, placement, and shadow behavior, and [symbols](symbols.md) for SF Symbols and custom fonts.
