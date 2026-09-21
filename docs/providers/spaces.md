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

## Name overrides

Set `spaces.names` to override names by position. The first entry names Space 1, the second names Space 2, and so on. Missing entries, `null`, and empty strings keep the default number. Extra entries are ignored.

Positions follow `spaces.scope` and `includeFullscreen`. With display scope, each display starts at the first name in the array. Reordering Spaces can change which Space receives each name.

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

Names appear in the default current label and in `{{name}}` and `{{value}}` templates, including workspace lists. `{{index}}` remains numeric and `{{workspaceId}}` keeps the native ID. Text names display literally, so template tags inside a name are not evaluated. Workspace lists keep their active-Space highlighting.

Names can contain Unicode symbols or Nerd Font glyphs. For example, use `"names": ["\uf121", "\uf0ac"]` with top-level `"style": {"fontFamily": "Symbols Nerd Font Mono"}` and install that font on your Mac. Plain strings always remain literal text, including strings that match SF Symbol names.

Use a `symbol` object for an SF Symbol. The same field accepts a font glyph object with its own font and optional size:

```json
{
  "id": "spaces",
  "type": "spaces",
  "spaces": {
    "names": [
      { "symbol": "terminal" },
      { "symbol": "globe" },
      "Chat",
      { "symbol": { "glyph": "\uf001", "font": "Symbols Nerd Font Mono" } },
      null
    ],
    "showSymbol": false
  },
  "text": "{{#workspaces}}{{name}}{{#separator}} · {{/separator}}{{/workspaces}}"
}
```

Name icons appear in the default current label and wherever a template inserts `{{name}}` or `{{value}}`. This also works inside workspace loops and conditional sections. Icons keep the entry's tint and active highlighting. Literal template text and `{{index}}` remain text.

For comparisons and accessibility, a name icon uses the default Space number. For example, `{{#name=2}}` matches Space 2 even when its label is a globe icon. Symbol names must not be blank. Choose an SF Symbol available on your version of macOS.

`spaces.showSymbol` and the top-level `symbol` control the separate provider icon. They do not hide or replace workspace name symbols. Set `text` to an empty string to hide all name content, including name symbols. Font glyph objects require their own `font`; they do not inherit `spaces.symbols.font`.

Use template conditions on `index` for further formatting or `workspaceId` to match native IDs. With `includeFullscreen:false`, an active fullscreen Space keeps the default text `Fullscreen`; the loop contains only desktop Spaces, with none highlighted. Use `{{^workspaces}}{{value}}{{/workspaces}}` to show a fallback for an empty list.

## Provider icon and colors

The provider icon appears beside the label by default. `spaces.showSymbol:false` hides it. `spaces.symbols.available` and `.unavailable` override the default `rectangle.3.group` and `questionmark` icons. They accept SF Symbol names or custom glyphs with shared `spaces.symbols.font` and `.size`. A top-level `symbol` overrides both states.

`spaces.tints.active` colors the current label or active list entry. `.inactive` colors other list entries, and `.unavailable` colors an unavailable state. Unspecified tints inherit the item style.

## Refresh behavior

The provider refreshes on Space switches, application activation, and display changes. Notification bursts coalesce, and incomplete transition snapshots receive bounded retries while retaining the previous snapshot. It uses private SkyLight APIs and shows `Spaces unavailable` when the requested Space or display cannot be read. Manual and event refresh modes capture the full snapshot, so each bar can render its own display from the same captured state.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
