# macOS Spaces

[Documentation index](../index.md#providers)

A `spaces` item shows native macOS Spaces without a window-manager integration. By default, every bar shows the focused Space's one-based position across displays, including fullscreen Spaces:

```json
{"id": "spaces", "type": "spaces"}
```

Set `spaces.scope` to `"display"` to show the Spaces belonging to each bar's display. When macOS shares Spaces across displays, bars use the shared Space list. `spaces.format` supports `"current"` (default), `"currentTotal"` (`2 / 4`), and `"list"` (all positions, with the active Space in bold). Lists are read-only.

```json
{
  "id": "spaces",
  "type": "spaces",
  "spaces": {
    "scope": "display",
    "format": "list",
    "labels": {"1": "Code", "2": "Web"},
    "tints": {"active": "#FFFFFF", "inactive": "#888888", "unavailable": "#FF6666"},
    "includeFullscreen": false
  }
}
```

Labels replace one-based positions within the selected scope after fullscreen filtering. Positions can change when Spaces are reordered, added, or removed; labels are not tied to persistent Space IDs. With `includeFullscreen:false`, an active fullscreen Space displays `Fullscreen` in current modes; a list shows the remaining desktop Spaces with none highlighted. If no desktop Spaces remain, it displays `Fullscreen`.

`spaces.showValue:false` displays only the symbol; `spaces.showSymbol:false` hides the symbol. Both default to `true`. `spaces.symbols.available` and `.unavailable` override the default `rectangle.3.group` and `questionmark` symbols. They accept SF Symbol names or custom glyphs with shared `spaces.symbols.font` and `.size`, like other providers. A top-level `symbol` overrides both states. `spaces.tints.active` colors the current value or active list entry; `.inactive` colors other list entries, and `.unavailable` colors an unavailable state. Unspecified tints inherit the item style.

The provider refreshes on Space switches, application activation, and display changes. Notification bursts coalesce, and incomplete transition snapshots receive bounded retries while retaining the previous snapshot. It uses private SkyLight APIs and shows `Spaces unavailable` when the requested Space or display cannot be read. Manual and event refresh modes capture the full snapshot, so each bar can render its own display from the same captured state.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
