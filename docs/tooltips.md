# Tooltips

[Documentation index](index.md)

Set an item's `tooltip` to show native macOS help when hovering over it. Text can
include provider tokens in braces and `\n` for multiple lines:

```json
{
  "id": "memory",
  "type": "memory",
  "memory": {
    "format": "percentage",
    "showLabel": false
  },
  "tooltip": "Memory: {used} / {total}\nUsage: {percentage}%"
}
```

Omitting `tooltip`, or setting it to `null`, keeps the existing tooltip: the item's
`label`, falling back to its `id`. Use `"tooltip": ""` to disable it. Whitespace-only
templates also disable it. Plain text works without tokens.

Tokens are case-sensitive. Unknown tokens and unmatched braces fail configuration
validation, including `sbar validate`. Use `{{` and `}}` for literal braces. Values
inserted into a template are literal text, even when they contain braces. Missing
or blank values display `—`; zero remains `0`.

Tooltips use the same provider state and refresh snapshot as the item. Hovering
does not run commands or request extra samples. Provider tokens remain available
when their readings are hidden from the bar label. Formatting uses the item's
scope, selected device or player, interfaces, smoothing, and units.

## Common tokens

These work on every item type:

| Token | Value |
| --- | --- |
| `{id}` | Item identifier |
| `{label}` | Configured label, falling back to the item identifier |
| `{text}` | Display text, including the text of any segments; hidden text becomes `—` |
| `{summary}` | Provider accessibility description, or display text for ordinary items |

`"tooltip": "{summary}"` is a useful default for an icon-only item. For a `datetime`
item, `{text}` and `{summary}` use its configured date format and refresh snapshot.
For groups and popups, these tokens describe the parent item; child items can have
their own tooltip templates.

## Provider tokens

All providers also accept the common tokens above.

| Provider | Additional tokens |
| --- | --- |
| `battery` | `{percentage}`, `{status}` |
| `volume` | `{percentage}`, `{status}` |
| `cpu` | `{percentage}`, `{status}` |
| `memory` | `{used}`, `{total}`, `{percentage}`, `{status}` |
| `disk` | `{free}`, `{used}`, `{total}`, `{percentage}`, `{path}`, `{status}` |
| `throughput` | `{download}`, `{upload}`, `{status}` |
| `media` | `{title}`, `{artist}`, `{source}`, `{status}` |
| `vpn` | `{names}`, `{count}`, `{status}` |
| `bluetooth` | `{names}`, `{count}`, `{status}` |
| `audioDevice` | `{name}`, `{device}`, `{status}` |
| `network` | `{interface}`, `{status}` |
| `aerospace` | `{workspace}`, `{workspaces}`, `{count}` |
| `yabai`, `spaces` | `{workspace}`, `{workspaces}`, `{index}`, `{count}` |
| `frontApplication` | `{name}` |
| `command`, `plugin` | `{output}`, `{status}`, `{error}` |

Percentages are whole numbers without a percent sign. Memory and disk values
include units using their existing macOS formatters. Disk `{percentage}` means
used space, and `{path}` is the expanded configured path. Throughput rates include
units even with `showUnits:false`, and both directions are available even when
one is hidden.

Battery status is `charging`, `plugged in`, `on battery`, or `AC power`. Volume
status is `available`, `muted`, `fixed`, or `unavailable`. CPU, memory, disk, and
throughput status is `available` or `unavailable` after receiving provider state.
Before the first reading, missing provider values use `—`.

Media `{source}` is the selected player's display name, such as `Music` or
`Spotify`. Status is `playing`, `paused`, `stopped`, or `unknown`.

VPN names and counts cover services whose state is not disconnected. Bluetooth
names and counts cover connected devices. Names form a comma-separated list;
an empty list displays `—`. Unavailable counts display `—`. Their `{status}` tokens
honor the provider's configured status labels.

Audio device `{name}` keeps the actual device name even when a configured label
replaces it in the bar. `{device}` is `input` or `output`; `{status}` is `available`,
`disconnected`, or `unavailable`. Network `{interface}` is the requested interface
type, or the detected type when none is requested. Its status is `connected` or
`disconnected`; filtering to Wi-Fi while Ethernet is active reports disconnected.

Workspace tokens follow the item's display scope and configured labels.
`{workspaces}` lists names separated by commas, and `{count}` counts those entries.
Spaces and Yabai lists omit fullscreen entries when `includeFullscreen:false`.
Spaces `{index}` is the position within that filtered scope; an excluded active
fullscreen Space has no index. Yabai keeps the original Mission Control index.

Command and plugin `{output}` contains the full retained result text, including
newlines, before display truncation. Status is `running`, `success`, or `failure`.
`{error}` contains the latest error, or `—` when absent. `onError: "keepLast"` keeps
the last successful output in the tooltip; other error behaviors discard it.
Output is subject to the provider's existing capture limits. This version does
not add custom JSON fields or expressions to templates.

## Try it

See the [tooltip example](../examples/tooltips/README.md) for a runnable config.
Native macOS tooltips control appearance and hover timing. Item actions and
click-to-open popups continue to work independently of tooltip text.
