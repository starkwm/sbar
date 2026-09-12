# Memory

[Documentation index](../index.md#providers)

Memory samples every two seconds and displays a `memorychip` icon with `RAM 8 GB`
by default. Configure its value and appearance under `memory`:

```json
{
  "id": "memory",
  "type": "memory",
  "text": "{{#available}}{{used}} / {{total}}{{/available}}{{^available}}—{{/available}}"
}
```

Use top-level `text` to choose `{{used}}`, `{{total}}`, or `{{percentage}}%`.
Bytes use macOS memory formatting; percentages round to the nearest whole percent.
Total is the installed physical RAM. `text: ""` displays an icon alone.
Set `memory.showSymbol: false` to display text only.
Customize `symbols.available` and `symbols.unavailable` (defaults `memorychip`
and `questionmark`). Glyphs inherit `symbols.font` and optional `symbols.size`,
with per-glyph overrides. An item-level `symbol` overrides both state symbols;
`showSymbol: false` hides it.

Memory usage is **active + wired + compressed physical pages**,
multiplied by the host page size. This is a specific VM-counter measure, not a claim
of equivalence with Activity Monitor's "Memory Used". It does not include every VM
category or measure memory pressure; the percentage uses this same numerator.

Startup, failed reads, or inconsistent counts display `RAM —` with an unavailable
icon, replacing the previous reading. A valid next sample restores the value.
Icon-only widgets retain used/total and percentage in their accessibility label.
Raw provider events retain used-byte formatting regardless of an item's display
mode. Refresh policies capture the full numeric state, including unavailable
readings; manual/interval items retain their snapshot until refreshed.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
