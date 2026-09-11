# CPU

[Documentation index](../index.md#providers)

CPU usage is the aggregate busy share across all cores, from 0–100%, sampled every
two seconds. The default widget displays a `cpu` icon and `CPU N%`, rounded to the
nearest whole percent.

```json
{
  "id": "cpu",
  "type": "cpu",
  "cpu": {
    "showLabel": false,
    "smoothingSamples": 3,
    "warningThreshold": 60,
    "highThreshold": 85,
    "tints": {
      "medium": "#EBCB8B",
      "high": "#BF616A",
      "unavailable": "#888888"
    }
  }
}
```

`showLabel`, `showPercentage`, and `showSymbol` default to `true`. Hide the label
for an icon with `N%`; hide both label and percentage for an icon alone. Use
`showSymbol: false` to display text only.

`warningThreshold` (default 60) and `highThreshold` (default 85) accept integers
from 0–100; warning must be below high. The rounded displayed percentage selects
`low` below warning, `medium` at or above warning, and `high` at or above high.
Customize these states and `unavailable` in `cpu.tints` and `cpu.symbols`.
Available states default to `cpu`; unavailable defaults to `questionmark`.
Tints fall back to the item/theme color. Symbols accept SF Symbol names or glyphs,
with shared `symbols.font` / `symbols.size` and per-glyph overrides.
An item-level `symbol` overrides state symbols; `showSymbol: false` hides it.

`smoothingSamples` accepts 1–30 (default 1, no smoothing). It averages the most
recent available samples before rounding, using fewer during warm-up. Each item
can choose its own window while sharing sampling across displays. Text, thresholds,
and accessibility all use the same smoothed percentage; raw provider events retain
the latest unsmoothed reading.

Startup, failed/unchanged samples, and sampling gaps longer than ten seconds display
`CPU —` and clear smoothing history. Failed reads and sampling restarts also reset
the counter baseline; a fresh interval is needed before showing usage again.
Icon-only widgets retain an accessibility label, including the unavailable state.
Refresh policies capture the sample history so manual/interval items retain their
entire presentation until refreshed.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
