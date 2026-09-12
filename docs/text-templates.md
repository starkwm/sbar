# Text templates

[Documentation index](index.md)

Set an item's `text` to control its label. Omit it to keep the existing provider presentation. An empty string hides the text while retaining the item's symbol. Groups, dividers, and spacers have no label and do not accept `text`.

```json
{ "id": "cpu", "type": "cpu", "text": "CPU {{percentage}}%" }
```

Plain strings work too, including on `text` and `popup` items. The old top-level `label` field has been removed; rename it to `text`.

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

## State-specific labels

Equality sections select a label for a particular state. Close them with the field name alone:

```json
{
  "id": "vpn",
  "type": "vpn",
  "text": "{{#status=connected}}Secure{{/status}}{{^status=connected}}{{value}}{{/status}}"
}
```

`{{#status=connected}}` includes its contents when the status equals `connected`.
`{{^status=connected}}` includes its contents when the status differs or is missing.
The example keeps the default provider label for every other state. Sections can
nest, including conditions on the same field.

Comparisons are case-sensitive string comparisons. Whitespace around the field,
`=`, and expected value is ignored. Expected values are unquoted text, so
`{{#title=A song}}...{{/title}}` matches that exact title. Numeric values compare
their formatted strings; there are no arithmetic or ordering comparisons. Empty
expected values are rejected; use `{{^field}}` to handle empty or missing fields.
Boolean comparisons accept `true` and `false`. Media `source` comparisons accept
`Music` and `Spotify`.

Allowed status values are validated for each provider. For example,
`{{#status=conected}}` fails configuration validation rather than silently hiding text.

| Provider | `status` values |
| --- | --- |
| `battery` | `charging`, `pluggedIn`, `onBattery`, `noBattery` |
| `volume` | `available`, `muted`, `fixed`, `unavailable` |
| `network` | `wifi`, `ethernet`, `cellular`, `other`, `offline` |
| `vpn` | `connecting`, `connected`, `disconnecting`, `disconnected`, `unavailable` |
| `bluetooth` | `on`, `off`, `connected`, `unauthorized`, `unavailable` |
| `audioDevice` | `available`, `disconnected`, `unavailable` |
| `media` | `playing`, `paused`, `stopped`, `unknown` |
| `mail` | `available`, `closed`, `unauthorized`, `unavailable` |
| `command`, `plugin` | `running`, `success`, `failure` |

Battery `noBattery` means no percentage reading, matching the existing `AC power`
fallback. Otherwise charging takes precedence over plugged-in power, then battery
power. Volume checks unavailable output first, then mute, then fixed volume with
no percentage, then adjustable volume. Zero volume is still `available`.

Status follows the same item snapshot and source selection as the other fields.
Network status respects interface filtering. VPN status is the aggregate status;
there is no iteration over individual services or devices yet.

## Provider fields

Every item with text supports `id` and `value`. `value` is the provider's default label. Retained state label maps, workspace formats, and throughput settings still affect their providers' defaults. For example, a clock can use `"text": "Time {{value}}"` alongside `"format": "HH:mm"`.

| Provider | Additional fields |
| --- | --- |
| `cpu` | `percentage`, `available` |
| `battery` | `percentage`, `charging`, `pluggedIn`, `available`, `status` |
| `volume` | `percentage`, `muted`, `available`, `status` |
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

Fields respect the selected media source, audio endpoint, disk path, network interface, CPU/throughput smoothing, and item refresh snapshots. Use the template to choose which fields appear; `text: ""` hides the label.

## First-pass limits

An explicit `text` replaces the whole textual presentation, including separate segments. A Spaces list loses per-Space highlighting, and throughput loses its per-direction symbols. A top-level item symbol remains available. Existing symbol, colour, and hide rules still apply. Native provider accessibility descriptions remain intact; static and clock labels use the rendered text.

Spaces, Aerospace, and Yabai currently expose only `value` and `id`; `value` follows the configured display scope. There is no per-entry template, custom number formatter, arbitrary command JSON field lookup, or literal `{{` escape yet. Date formatting still uses the clock's `format`, `dateStyle`, and `timeStyle` fields. Command and plugin `value` retains the existing truncation and error policy. Templates affect presentation only; CLI values and subscription events retain their existing output.

Try the [Everyday bar](../examples/everyday/config.json), which uses templates for its labels:

```sh
.build/debug/sbar validate --config "$PWD/examples/everyday/config.json"
.build/debug/sbar start --config "$PWD/examples/everyday/config.json"
```

## Migrating older configurations

Removed text settings now fail configuration loading with the full field path and a reminder to use top-level `text`. A failed reload keeps the last valid configuration.

| Removed setting | Replacement on the item |
| --- | --- |
| `label` | `text` with the same string |
| Battery/volume `showPercentage: false` | `"text": ""` |
| CPU `showLabel: false` | `"text": "{{percentage}}%"` |
| CPU `showPercentage` | Choose literal text, percentage, or an empty string |
| Memory/disk `format`, `showLabel`, `showValue` | Choose `used`, `free`, `total`, or `percentage` fields and write any label in the template |
| Network/VPN/Bluetooth/audio-device `showLabel: false` | `"text": ""` |
| VPN/Bluetooth `showName: false` | `"text": "VPN {{status}}"` or `"text": "Bluetooth {{status}}"` |
| Media `showTitle`, `showArtist`, `separator` | Choose title/artist fields and put the separator inside a conditional section |
| Command/plugin `showValue: false` | `"text": ""` |
| Network/audio-device `labels` | Equality sections such as `{{#status=available}}Ready{{/status}}{{^status=available}}{{value}}{{/status}}` using that provider's states |

Wrap readings in an `available` section when you need an unavailable fallback. Network and audio-device `labels` maps have been removed; use equality sections instead. Bluetooth and VPN maps remain supported because they can format each device or service separately. Workspace formats and label maps, throughput display options, clock formatting, and command output format remain supported. Provider symbols, tints, hide rules, and data-selection settings are unchanged.
