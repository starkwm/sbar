# Throughput

[Documentation index](../index.md#providers)

Throughput samples every two seconds, calculates download/upload deltas separately
for each non-loopback interface, then combines the rates. Configure an item with:

```json
{
  "id": "throughput",
  "type": "throughput",
  "text": "{{#transfers}}{{symbol}}{{value}}{{#separator}} · {{/separator}}{{/transfers}}{{^transfers}}{{value}}{{/transfers}}",
  "throughput": {
    "interfaces": ["en0"],
    "unit": "bytes",
    "smoothingSamples": 3
  }
}
```

Omit `interfaces` to total all non-loopback interfaces, including tunnels.
Specify a nonempty list of unique interface names to restrict sampling results;
interface names depend on the machine and do not imply Wi-Fi or Ethernet.
Explicitly selected interfaces must all have valid readings; a missing, newly
appeared, or reset interface makes that item's reading unavailable. With no filter,
only interfaces with valid deltas contribute, and new/reset interfaces join after
a fresh interval. If none have valid deltas, the item is unavailable.
Loopback interfaces are excluded even when named explicitly.

`unit` is `bytes` (default) or `bits`. Rates scale automatically through
B/s, KiB/s, MiB/s, GiB/s for bytes, or bit/s, kbit/s, Mbit/s, Gbit/s for bits.
Values round to at most one decimal place, retaining small rates such as
`0.5 B/s`.

Use `text` to choose directions, values, and units. `download` and `upload` contain
formatted rates; `download.value` / `upload.value` contain the scaled number, and
`download.unit` / `upload.unit` contain its suffix. `available` is false until a
reading exists. Unavailable rate fields are empty.

The `transfers` loop contains download then upload. Each entry exposes `direction`
(`download` or `upload`), `value` (formatted rate), `number`, `unit`, `index`,
`first`, and `last`. `total` is two when available, otherwise zero.
`{{symbol}}` requests the entry's native direction symbol, which follows the item's
`symbolPosition`. It must be used inside the loop. Repeated symbol tags in the same
text run produce one icon. Separate entries with `{{#separator}}...{{/separator}}`.

Examples:

- Numbers without units: `{{#transfers}}{{symbol}}{{number}}{{#separator}} · {{/separator}}{{/transfers}}`
- Download only: `{{#transfers}}{{#direction=download}}{{symbol}}{{value}}{{/direction}}{{/transfers}}`
- Direction icons only: `{{#transfers}}{{symbol}}{{#separator}} {{/separator}}{{/transfers}}`
- Combined text: `Down {{download.value}} {{download.unit}} / Up {{upload.value}} {{upload.unit}}`

Wrap scalar text in `{{#available}}...{{/available}}` and add
`{{^available}}—{{/available}}` for unavailable readings. Omit `text` to keep the
standard two-direction display. `text: ""` hides its text and directional icons;
an item-level or unavailable icon still follows `showSymbol`.

`showDownload`, `showUpload`, `showValue`, and `showUnits` have been removed;
configurations using them report a migration error. `showSymbol` still defaults to
`true`. Accessibility always includes both direction names and full units when
rates are available, regardless of the visible template.

Customize `symbols.download`, `symbols.upload`, and `symbols.unavailable`
(defaults `arrow.down`, `arrow.up`, `questionmark`). Glyphs inherit `symbols.font`
and optional `symbols.size`, with per-glyph overrides. An item-level `symbol`
replaces the directional symbols with one fixed icon; `showSymbol: false` hides it.

`smoothingSamples` accepts 1–30 (default 1, no smoothing). Each interface's recent
rates are averaged before summing; fewer samples are used during warm-up.
Items can select different interfaces and windows while sharing native sampling
across displays. Provider events retain unsmoothed, all-interface rates in bytes.

Timing uses a monotonic clock. Startup, failed reads, sampling restarts, and gaps
longer than ten seconds clear baselines/history and show `—` with an unavailable
icon until a fresh interval exists. Counter decreases (reset or wraparound) and
interface identity changes reset only that interface's history, without generating
a traffic spike. Unchanged counters are a valid zero rate. Removed interfaces
are discarded immediately. Refresh policies capture the full per-interface
history, so manual/interval items retain their presentation until refreshed.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
