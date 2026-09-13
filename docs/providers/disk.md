# Disk

[Documentation index](../index.md#providers)

Disk samples every two seconds and displays an `internaldrive` icon with
`120 GB free` by default. Select a volume with an existing file or directory on it:

```json
{
  "id": "external",
  "type": "disk",
  "disk": {
    "path": "/Volumes/External",
    "warningThreshold": 20,
    "criticalThreshold": 10,
    "tints": {
      "warning": "#EBCB8B",
      "critical": "#BF616A",
      "unavailable": "#888888"
    }
  },
  "text": "{{#available}}{{used}} / {{total}} used{{/available}}{{^available}}—{{/available}}"
}
```

`path` defaults to the home directory and accepts absolute paths or `~` expansion.
It may refer to a file or directory; capacity describes its containing filesystem.
Paths on the same volume share one capacity read per sampling pass, across items
and displays. Missing paths, failed reads, or invalid capacities produce an
unavailable icon and `— unavailable`, then recover on a valid sample.

The provider checks the mount before and after reading. Once a path has produced
a valid reading, a change to a different mount point is treated as unavailable,
so an unmounted drive cannot silently turn into a reading for its parent disk.
Leftover directories under `/Volumes` are also rejected unless on that mounted
volume. This tracks the volume at a path, not a persistent physical-drive identity.

Use top-level `text` with `{{free}}`, `{{used}}`, `{{total}}`, or `{{percentage}}%`.
Percentage means used space and rounds to the nearest whole percent. Use an
`available` section to handle missing readings. `text: ""` displays an icon alone;
`disk.showSymbol: false` displays text only. Accessibility retains the path,
free/total capacity, and used percentage.

`warningThreshold` (default 20) and `criticalThreshold` (default 10) are percentages
**free**, from 0–100; critical must be below warning. Tints apply at or below each
threshold, with critical taking precedence. Comparison uses the unrounded free
percentage. Customize `tints.normal`, `warning`, `critical`, and `unavailable`;
omitted colors fall back to the item/theme tint.

`symbols.available` and `symbols.unavailable` default to `internaldrive` and
`questionmark`. Glyphs inherit `symbols.font` and optional `symbols.size`, with
per-glyph overrides. An item-level `symbol` overrides both states, and
`showSymbol: false` hides it.

Free and total bytes come from `FileManager.attributesOfFileSystem` using
`systemFreeSize` and `systemSize`; used is total minus free. Bytes use macOS file
size formatting. This preserves the existing free-space measurement and does not
add an estimate of reclaimable storage.

Disk value events use each **item ID**, with free-space text regardless of
the text template. Refresh policies capture each item's full capacity state; manual
items hold their snapshot until triggered. Changing an item's path clears its old
snapshot immediately.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
