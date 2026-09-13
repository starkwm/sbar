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

## Section backgrounds

Use `theme.regionStyle` for shared section styling and `theme.regions.left`,
`center`, and `right` for individual overrides. Each field inherits independently
when omitted or null. Explicit zero values and transparent colors override shared
settings. Item styles remain independent.

```json
{
  "background": "#00000000",
  "verticalPadding": 4,
  "regionStyle": {
    "background": "#1A1B26",
    "cornerRadius": 8,
    "horizontalPadding": 10,
    "verticalPadding": 2,
    "borderColor": "#414868",
    "borderWidth": 1
  },
  "regions": {
    "center": { "background": "#24283B" },
    "right": { "cornerRadius": 12 }
  }
}
```

The example above is the contents of `theme`. Section backgrounds fit the visible
items, padding, and overflow button. A flexible spacer can expand the section to
its allocated width. Empty sections draw nothing, including when all their items
are hidden by providers. Alignment and notch placement remain unchanged.

Section styles support `background` and `borderColor`, `borderWidth` and
`cornerRadius` from 0–48 points, `horizontalPadding` and `itemSpacing` from 0–96,
and `verticalPadding` from 0–48. Colors use the same RGB and RGBA syntax as item
colors. Backgrounds and borders default to transparent; border width, corner
radius, and padding default to zero. Spacing falls back to `theme.itemSpacing`,
then 10 points. Set both `borderColor` and `borderWidth` to show a border. Borders
draw inside the section bounds.

Padding reduces available item space and can move items into overflow. It is
clamped to half the allocated dimension; sections never increase `bar.height`.
The section fills the bar's inner height, after the theme's outer vertical padding.
Oversized contents remain clipped to the section. Section decoration adds no new
click targets, so mouse pass-through continues to use item bounds.

The whole-bar background and corner radius still apply. Use a transparent
`theme.background` and `bar.shadow: false` for separate floating sections.
An omitted whole-bar background still uses the system material. Section shadows
and material backgrounds are not supported.

See the [sections example](../examples/sections/README.md) for a complete configuration.

## Hover colours

Use `hoverTint` and `hoverBackground` in `theme.itemStyle` for defaults, or in an item's `style` for overrides. They apply to items with a primary action, secondary action, or popup:

```json
{
  "schemaVersion": 1,
  "bar": {},
  "theme": {
    "itemStyle": {
      "horizontalPadding": 8,
      "verticalPadding": 4,
      "cornerRadius": 7,
      "hoverTint": "#FFFFFF",
      "hoverBackground": "#3B4261"
    }
  },
  "items": {
    "right": [
      {
        "id": "cpu",
        "type": "cpu",
        "primaryAction": { "kind": "application", "value": "com.apple.ActivityMonitor" },
        "style": { "background": "#292E42", "hoverBackground": "#414868" }
      }
    ]
  }
}
```

Both colours accept `#RRGGBB` and `#RRGGBBAA` and inherit independently when omitted or null. `hoverTint` overrides the normal text and symbol tint, including provider state and segment colours. Native application icons keep their original colours. Without `hoverTint`, the normal tint remains.

`hoverBackground` replaces the normal item background while hovered. An explicit transparent colour clears the background during hover; use the normal background colour to keep it unchanged. Without a configured hover background, sbar draws an 8% system-primary-colour highlight over the normal background. The highlight uses the item's corner radius and covers its full width and padding. Non-interactive items do not change on hover.

## Item widths

Use `style.minWidth` to reserve space for changing labels, such as percentages or transfer rates:

```json
{
  "id": "battery",
  "type": "battery",
  "style": { "minWidth": 80, "alignment": "trailing" }
}
```

The item stays at least 80 points wide. Labels that need more space can grow, so choose a minimum that fits the longest expected label to avoid shifting nearby items.

Use `style.width` when an item must keep the same width even for longer labels:

```json
{
  "id": "app",
  "type": "frontApplication",
  "style": { "width": 160, "alignment": "leading" }
}
```

Fixed-width labels stay on one line and truncate at the end. Content that cannot fit, such as a large symbol or group, is clipped to the item bounds. `width` takes precedence over `minWidth`, including inherited values.

Both widths accept 0–4096 points and include the symbol, label, and padding. `alignment` accepts `leading`, `center`, or `trailing` and defaults to `center`. The background and hover area cover the reserved width. Overflow selection respects the reserved space and moves items to the overflow menu when needed.

These fields also work in `theme.itemStyle`. Each field inherits independently when omitted or null. An explicit `minWidth` of `0` clears an inherited minimum; an explicit `width` of `0` reserves no width. Without either width setting, items size to their content as before.
