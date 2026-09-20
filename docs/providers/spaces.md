# macOS Spaces

[Documentation index](../index.md#providers)

A `spaces` item shows native macOS Spaces without a window-manager integration. By default, every bar shows the focused Space's one-based position across displays, including fullscreen Spaces:

```json
{"id": "spaces", "type": "spaces"}
```

Set `spaces.scope` to `"display"` to show the Spaces belonging to each bar's display. When macOS shares Spaces across displays, bars use the shared Space list. Use top-level [workspace templates](../text-templates.md#workspace-fields-and-lists) for current/total labels or lists. Lists are read-only and preserve active-Space highlighting.

```json
{
  "id": "spaces",
  "type": "spaces",
  "spaces": {
    "scope": "display",
    "tints": {
      "active": "#FFFFFF",
      "inactive": "#888888",
      "unavailable": "#FF6666"
    },
    "includeFullscreen": false
  },
  "text": "{{#workspaces}}{{name}}{{#separator}} · {{/separator}}{{/workspaces}}{{^workspaces}}{{value}}{{/workspaces}}"
}
```

Set `spaces.names` to override names by position. The first array entry names Space 1, the second names Space 2, and so on. Missing entries, `null`, and empty strings keep the default number; extra entries are ignored. Names follow the selected scope and fullscreen filter, so display scope starts at the first name on each display. Reordering Spaces can change which Space receives each name.

```json
{
  "id": "spaces",
  "type": "spaces",
  "spaces": {
    "names": ["Code", "Web", null, "Chat"],
    "includeFullscreen": false
  }
}
```

Names apply to the default current label and to `{{name}}` and `{{value}}` in templates, including workspace lists. `{{index}}` remains numeric and `{{workspaceId}}` keeps the native ID. Names are literal text, so template tags within a name are not evaluated. Active-Space highlighting is preserved.

Names can contain Unicode symbols or Nerd Font glyphs. For example, use `"names": ["\uf121", "\uf0ac"]` with top-level `"style": {"fontFamily": "Symbols Nerd Font Mono"}` and install that font on your Mac. These are text labels; SF Symbol names are not rendered as per-workspace icons.

Use template conditions on `index` for further formatting or `workspaceId` to match native IDs. With `includeFullscreen:false`, an active fullscreen Space keeps the default text `Fullscreen`; the loop contains only desktop Spaces, with none highlighted. Use `{{^workspaces}}{{value}}{{/workspaces}}` to show a fallback for an empty list.

Top-level `text: ""` displays only the symbol; `spaces.showSymbol:false` hides the symbol, which is shown by default. `spaces.symbols.available` and `.unavailable` override the default `rectangle.3.group` and `questionmark` symbols. They accept SF Symbol names or custom glyphs with shared `spaces.symbols.font` and `.size`, like other providers. A top-level `symbol` overrides both states. `spaces.tints.active` colors the current value or active list entry; `.inactive` colors other list entries, and `.unavailable` colors an unavailable state. Unspecified tints inherit the item style.

The provider refreshes on Space switches, application activation, and display changes. Notification bursts coalesce, and incomplete transition snapshots receive bounded retries while retaining the previous snapshot. It uses private SkyLight APIs and shows `Spaces unavailable` when the requested Space or display cannot be read. Manual and event refresh modes capture the full snapshot, so each bar can render its own display from the same captured state.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
