# Text templates

[Documentation index](index.md)

Set an item's `text` to control its label. Omit it to keep the existing provider presentation. An empty string hides the text while retaining the item's symbol. Groups, dividers, and spacers have no label and do not accept `text`.

```json
{ "id": "cpu", "type": "cpu", "text": "CPU {{percentage}}%" }
```

Plain strings work too, including on `text` and `popup` items. `text` takes precedence over `label`. Existing configurations continue to work.

## Values and conditional sections

`{{field}}` inserts a value. Spaces around the field name are allowed. Values are inserted as plain text, without HTML escaping or further template evaluation. Missing values become empty strings.

`{{#field}}...{{/field}}` includes its contents when the value is present. `{{^field}}...{{/field}}` includes its contents when the value is missing, empty, or false. Numeric zero counts as present. Sections can nest up to eight levels.

An optional artist avoids a stray separator:

```json
{
  "id": "media",
  "type": "media",
  "text": "{{#artist}}{{artist}}: {{/artist}}{{title}}{{^title}}Nothing playing{{/title}}"
}
```

Use an availability section for readings that may be missing:

```json
{
  "id": "memory",
  "type": "memory",
  "text": "{{#available}}RAM {{used}} / {{total}}{{/available}}{{^available}}RAM unavailable{{/available}}"
}
```

Unknown fields, unmatched tags, and unclosed sections fail configuration validation. A failed reload retains the previous configuration.

## Provider fields

Every item with text supports `id` and `value`. `value` is the existing formatted label, including the effects of the provider's text settings. For example, a clock can use `"text": "Time {{value}}"` alongside `"format": "HH:mm"`.

| Provider | Additional fields |
| --- | --- |
| `cpu` | `percentage`, `available` |
| `battery` | `percentage`, `charging`, `pluggedIn`, `available` |
| `volume` | `percentage`, `muted`, `available` |
| `memory` | `used`, `total`, `percentage`, `usedBytes`, `totalBytes`, `available` |
| `disk` | `used`, `free`, `total`, `percentage`, `freeBytes`, `totalBytes`, `available` |
| `media` | `title`, `artist`, `source`, `status`, `playing`, `available` |
| `mail` | `unreadCount`, `status`, `available` |
| `throughput` | `download`, `upload`, `available` |
| `network` | `status`, `connected` |
| `vpn` | `status`, `names`, `connected`, `available` |
| `bluetooth` | `status`, `names`, `count`, `connected` |
| `audioDevice` | `name`, `status`, `available` |
| `frontApplication` | `name` |
| `command`, `plugin` | `status`, `error` |

Percentages are rounded whole numbers without `%`. Memory and disk sizes include units. Throughput rates include units and respect the configured bits/bytes setting. Boolean values render as `true` or `false`. Status fields use the provider's status names; command and plugin statuses are `running`, `success`, and `failure`. Media `source` is `Music` or `Spotify`.

VPN `names` contains active service names. Bluetooth `names` contains connected device names, and `count` is the device count. Both name lists are sorted and comma-separated.

Fields respect the selected media source, audio endpoint, disk path, network interface, CPU/throughput smoothing, and item refresh snapshots. Provider text visibility settings do not suppress individual fields such as `percentage` or `title`.

## First-pass limits

An explicit `text` replaces the whole textual presentation, including separate segments. A Spaces list loses per-Space highlighting, and throughput loses its per-direction symbols. A top-level item symbol remains available. Existing symbol, colour, and hide rules still apply. Native provider accessibility descriptions remain intact; static and clock labels use the rendered text.

Spaces, Aerospace, and Yabai currently expose only `value` and `id`; `value` follows the configured display scope. There is no per-entry template, custom number formatter, arbitrary command JSON field lookup, or literal `{{` escape yet. Date formatting still uses the clock's `format`, `dateStyle`, and `timeStyle` fields. Command and plugin `value` retains the existing truncation and error policy. Templates affect presentation only; CLI values and subscription events retain their existing output.

Try the [Everyday bar](../examples/everyday/config.json), which uses templates for its labels:

```sh
.build/debug/sbar validate --config "$PWD/examples/everyday/config.json"
.build/debug/sbar start --config "$PWD/examples/everyday/config.json"
```
