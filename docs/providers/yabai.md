# Yabai

[Documentation index](../index.md#providers)

A `yabai` item shows the focused Space's Yabai label, falling back to its Mission Control index when the label is absent or blank. It polls independently every two seconds and captures structured Space and display data.

```json
{
  "id": "yabai",
  "type": "yabai",
  "yabai": {
    "scope": "display",
    "format": "list",
    "includeFullscreen": false,
    "tints": {"focused": "#FFFFFF", "visible": "#88CCFF", "inactive": "#888888"}
  }
}
```

`yabai.scope` is `"focused"` (default, across displays) or `"display"` (each bar's display). `format` is `"current"` (default) or `"list"` (read-only, with the focused Space bold). Display scope shows that display's visible Space in current mode. Display indexes are mapped using Yabai's display UUIDs, so custom Yabai display ordering is supported.

`includeFullscreen` defaults to `true`. When disabled, lists omit native fullscreen Spaces without renumbering the remaining Mission Control indexes. An active fullscreen Space displays `Fullscreen` in current mode; lists retain other Spaces without highlighting the excluded Space. If the filtered list is empty, the value is `Fullscreen`. Labels come from Yabai and blank labels fall back to indexes; indexes may change when Spaces are added, removed, or reordered.

`showValue:false` shows only the symbol; `showSymbol:false` hides the symbol. Both default to `true`. `symbols.available` and `.unavailable` override `rectangle.3.group` and `questionmark`, and accept SF Symbol names or custom glyphs with shared `symbols.font` and `.size`. A top-level `symbol` overrides both states. `tints.focused`, `.visible`, `.inactive`, and `.unavailable` customize colors; focused takes precedence over visible, and unspecified tints inherit the item style.

Manual/event triggers request fresh queries before capturing the result. Interval refresh captures the latest polled snapshot. Existing Yabai signals can invoke `sbar trigger <item-id>` for an item with manual/event refresh configured; sbar does not install signals or change Yabai configuration. Refresh bursts coalesce, cancelled queries cannot publish, and incomplete snapshots receive up to three attempts while retaining the previous value. Each CLI invocation has a two-second timeout; a snapshot queries displays, Spaces, then displays again to check the mapping. Polling does not overlap an in-flight refresh.

Missing installations display `Yabai not installed`; failed, malformed, or inconsistent reads display `Yabai unavailable` after retries. stdout is parsed separately from diagnostics. Executables are located in PATH or the standard Homebrew prefixes.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
