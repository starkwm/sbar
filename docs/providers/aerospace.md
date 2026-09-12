# Aerospace

[Documentation index](../index.md#providers)

An `aerospace` item shows the focused Aerospace workspace name by default. It queries structured workspace data independently every two seconds, with a two-second timeout. Executables are located in PATH or the standard Homebrew prefixes. Missing installations display `Aerospace not installed`; failed, empty, malformed, or incompatible CLI output displays `Aerospace unavailable`. The provider uses `list-workspaces --all --json --format` with workspace focus, visibility, and AppKit monitor-index fields; the installed Aerospace version must support those fields.

```json
{
  "id": "aerospace",
  "type": "aerospace",
  "aerospace": {
    "scope": "display",
    "tints": {
      "focused": "#FFFFFF",
      "visible": "#88CCFF",
      "inactive": "#888888"
    }
  },
  "text": "{{#workspaces}}{{name}}{{#separator}} · {{/separator}}{{/workspaces}}{{^workspaces}}{{value}}{{/workspaces}}"
}
```

`aerospace.scope` is `"focused"` (default, across all monitors) or `"display"` (the workspaces on each bar's display). Use top-level [workspace templates](../text-templates.md#workspace-fields-and-lists) for current labels and read-only lists that preserve focused-workspace emphasis. In display scope, current mode shows that monitor's visible workspace, even when another monitor has focus. Monitor indexes are mapped to display UUIDs when querying; a display-layout change during the query invalidates that result.

Use equality conditions on `name` to rename workspaces in the template. Top-level `text: ""` shows only the symbol; `showSymbol:false` hides the symbol, which is shown by default. `symbols.available` and `symbols.unavailable` override `rectangle.3.group` and `questionmark`, and accept SF Symbol names or custom glyphs with shared `symbols.font` and `.size`. The top-level `symbol` overrides both states. `tints.focused`, `.visible`, `.inactive`, and `.unavailable` customize state colors; focused takes precedence over visible. Unspecified colors inherit the item style.

Manual/event triggers request a fresh Aerospace query and capture its completed snapshot. Bursts coalesce and superseded queries cannot publish stale results. Background polling continues independently; interval refresh captures the latest polled snapshot. To reduce workspace-switch latency, an existing Aerospace workspace-change callback can invoke `sbar trigger <item-id>` with the bar's socket option. The item must have a manual or event `refresh` configuration. sbar does not modify Aerospace configuration.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
