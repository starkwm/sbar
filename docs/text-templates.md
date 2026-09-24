# Text templates

[Documentation index](index.md)

Set an item's `text` to control its label. Omit it to keep the existing provider presentation. An empty string hides the label while retaining the item's separate symbol. It also hides throughput direction icons and Spaces name icons. Groups, dividers, and spacers have no label and do not accept `text`.

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
| `weather` | `available`, `stale`, `unavailable` |
| `mail` | `available`, `closed`, `unauthorized`, `unavailable` |
| `calendar` | `loading`, `upcoming`, `ongoing`, `empty`, `unauthorized`, `unavailable` |
| `command`, `plugin` | `running`, `success`, `failure` |

Battery `noBattery` means no percentage reading, matching the existing `AC power`
fallback. Otherwise charging takes precedence over plugged-in power, then battery
power. Volume checks unavailable output first, then mute, then fixed volume with
no percentage, then adjustable volume. Zero volume is still `available`.

Status follows the same item snapshot and source selection as the other fields.
Network status respects interface filtering. VPN status is the aggregate status outside a service loop, and the individual
service status inside it. Bluetooth status inside a device loop is `connected`.

## Workspace fields and lists

Spaces, Aerospace, and Yabai support the same workspace fields. Outside a loop,
they describe the current workspace selected by the provider's `scope`. Inside
`{{#workspaces}}...{{/workspaces}}`, they describe each workspace in order.

```json
{
  "id": "spaces",
  "type": "spaces",
  "text": "{{#workspaces}}{{#index=1}}Code{{/index}}{{^index=1}}{{name}}{{/index}}{{#separator}} · {{/separator}}{{/workspaces}}{{^workspaces}}{{value}}{{/workspaces}}",
  "spaces": { "scope": "display", "includeFullscreen": false }
}
```

The example renames the first Space to Code and retains per-Space highlighting.
For names assigned by position, set [`spaces.names`](providers/spaces.md#name-overrides). Text entries become the default label and the `name` and `value` fields. Symbol objects render an icon at each `{{name}}` or `{{value}}` insertion. Comparisons use the default Space number for name icons. `index` remains numeric.
Use `{{#separator}} · {{/separator}}` inside the loop for a separator between entries. It uses the provider's inactive tint and is never bold. Without an inactive tint it inherits the item colour. Ordinary literal text inside the loop still inherits that entry's styling. No extra spacing is inserted between template runs.
`{{^workspaces}}` supplies a fallback when the list is empty or unavailable.
Workspace loops cannot nest and cannot be compared or inserted as a scalar value.

| Field | Meaning |
| --- | --- |
| `name` | Native display name; Spaces uses its `names` override or one-based position, Yabai falls back to its Mission Control index |
| `index` | Spaces position after scope/fullscreen filtering; Aerospace position in the scoped query order; Yabai's original Mission Control index |
| `workspaceId` | Native Space/Yabai ID, or Aerospace workspace name |
| `total` | Number of entries after scope/fullscreen filtering |
| `active` | The current workspace for this item's scope |
| `focused` | The globally focused workspace |
| `visible` | Currently visible on a display |
| `fullscreen` | Native fullscreen Space; always false for Aerospace |
| `available` | Whether the current workspace is available |
| `first`, `last` | First/last entry in the source list, available inside a loop |
| `value` | Default current label outside a loop; entry name inside it |
| `id` | Item ID, including inside a loop |

Spaces highlights the active entry. Aerospace and Yabai emphasise the globally
focused entry and retain their focused/visible/inactive tints. Hover tint still
overrides all entry colours. Templates do not add per-workspace click actions.

`includeFullscreen: false` excludes fullscreen entries from loops. A current
fullscreen Space still has `fullscreen: true`; its default `value` is `Fullscreen`.
Native Spaces has no filtered index for that excluded entry. Yabai retains its
native index and name. `available` can be true with an empty filtered list.
Unavailable snapshots have no current fields, `available: false`, and `total: 0`.

For current/total labels with a fullscreen or unavailable fallback, use
`{{#index}}{{index}} / {{total}}{{/index}}{{^index}}{{value}}{{/index}}`.
Scope selection and loops use the same captured snapshot as the provider's default
presentation. Reordering can change positional indexes; `workspaceId` identifies
the source workspace instead.

## VPN services and Bluetooth devices

VPN supports `{{#services}}...{{/services}}` and Bluetooth supports
`{{#devices}}...{{/devices}}`. Each loop exposes the entry's name and status,
so state-specific labels no longer need provider `labels` maps.

```json
{
  "id": "vpn",
  "type": "vpn",
  "text": "{{#services}}{{name}}: {{#status=connected}}Secure{{/status}}{{^status=connected}}{{status}}{{/status}}{{#separator}}, {{/separator}}{{/services}}{{^services}}{{value}}{{/services}}"
}
```

```json
{
  "id": "bluetooth",
  "type": "bluetooth",
  "text": "{{#devices}}{{name}} linked{{#separator}}, {{/separator}}{{/devices}}{{^devices}}{{value}}{{/devices}}"
}
```

`services` includes all monitored VPN services, including disconnected ones, when
the service list is available. This differs from the default VPN `value`, which
lists active services only. `devices` includes connected Bluetooth devices only.
If Bluetooth is off, unauthorized, or unavailable, the device collection is empty.
Unavailable VPN service lists are empty too; stale entries are not rendered.
Inverse sections supply a fallback for an empty list.

Entries sort by provider name, with their identifier breaking ties. Names collapse
whitespace to one line; unnamed entries use `VPN` or `Unnamed device`. Values are
inserted literally, without evaluating template syntax contained in a name.

| Field | Meaning inside a loop |
| --- | --- |
| `name` | Service or device name |
| `status` | Individual VPN service status, or `connected` for a Bluetooth device |
| `connected` | Whether the entry is connected |
| `available` | VPN service status is not `unavailable` |
| `serviceId`, `deviceId` | Provider identifier, available for the corresponding collection |
| `index` | One-based position in the sorted list |
| `first`, `last` | Position flags for the source list |
| `value` | Default entry label, such as `Work connected` |
| `total` | Collection count, also available outside the loop |
| `id` | The containing item ID |

Outside a loop, `status`, `connected`, `available`, and `value` retain their
existing aggregate meanings. Entry-only fields are empty outside a loop.
`{{#separator}}...{{/separator}}` emits text between source entries, without a
trailing separator. Separators follow rendered entries, so conditions hiding entries do not leave stray punctuation. Entries containing only a separator are omitted. Whitespace and symbol tags count as content. `first`, `last`, `index`, and `total` still describe the source list; inverse collection sections test whether the source list is empty. Loops cannot nest or be compared, and each provider accepts only
its own collection name. Unknown fields and invalid status comparisons fail
configuration validation.

VPN and Bluetooth loops produce plain text with the item's aggregate symbol and
tint. Native accessibility descriptions and hide rules remain intact. They use
the same captured provider state as other template fields, including manual and
interval snapshots. They do not trigger extra device scans or service queries.

## Provider fields

Every item with text supports `id`, `value`, and `symbol`. `value` is the provider's default label. For example, a clock can use `"text": "Time {{value}}"` alongside `"format": "HH:mm"`.

| Provider | Additional fields |
| --- | --- |
| `cpu` | `percentage`, `available` |
| `battery` | `percentage`, `charging`, `pluggedIn`, `available`, `status` |
| `volume` | `percentage`, `muted`, `available`, `status` |
| `memory` | `used`, `total`, `percentage`, `usedBytes`, `totalBytes`, `available` |
| `disk` | `used`, `free`, `total`, `percentage`, `freeBytes`, `totalBytes`, `available` |
| `media` | `title`, `artist`, `source`, `status`, `playing`, `available` |
| `mail` | `unreadCount`, `status`, `available` |
| `calendar` | `title`, `calendar`, `startTime`, `endTime`, `minutesUntil`, `allDay`, `status`, `available` |
| `throughput` | `download`, `upload`, `download.value`, `download.unit`, `upload.value`, `upload.unit`, `available`, `transfers`, `direction`, `number`, `unit`, `symbol`, `index`, `total`, `first`, `last`, `separator` |
| `network` | `status`, `connected` |
| `vpn` | `status`, `names`, `connected`, `available`, plus [service fields](#vpn-services-and-bluetooth-devices) |
| `bluetooth` | `status`, `names`, `count`, `connected`, plus [device fields](#vpn-services-and-bluetooth-devices) |
| `audioDevice` | `name`, `status`, `available` |
| `frontApplication` | `name` |
| `command`, `plugin` | `status`, `error` |
| `spaces`, `aerospace`, `yabai` | See [workspace fields](#workspace-fields-and-lists) |

Percentages are rounded whole numbers without `%`. Memory and disk sizes include units. Throughput rates include units and respect the configured bits/bytes setting. Boolean values render as `true` or `false`. Status fields use the provider's status names; command and plugin statuses are `running`, `success`, and `failure`. Media `source` is `Music` or `Spotify`.

VPN `names` contains active service names. Bluetooth `names` contains connected device names, and `count` is the device count. Both name lists are sorted and comma-separated.

Fields respect the selected media source, audio endpoint, disk path, network interface, CPU/throughput smoothing, and item refresh snapshots. Use the template to choose which fields appear; `text: ""` hides the label.

Weather fields include temperature, conditions, humidity, wind, and stale status.
See [weather](providers/weather.md) for the complete field list and units.

## Symbols

`{{symbol}}` requests the provider's native symbol or the item's explicit symbol.
It does not insert a symbol name as text. The icon follows `symbolPosition`,
regardless of where the tag appears within the text. Repeated tags retain one
aggregate icon, except that throughput loops have one icon per direction run.

Templates without a symbol tag preserve the provider's existing icon behavior.
When a template contains the tag, the icon appears only if a branch containing
that tag renders. For example, this shows the battery icon only while charging:

```json
{
  "id": "battery",
  "type": "battery",
  "text": "{{#charging}}{{symbol}}{{/charging}}{{percentage}}%"
}
```

`showSymbol: false` hides provider symbols, including those requested by `{{symbol}}`. Spaces name icons remain part of the label. Native application icons follow the same
template conditions and still require `frontApplication.showIcon`. Workspace,
VPN, and Bluetooth loops use the aggregate icon for `{{symbol}}`. Spaces can separately replace entry names with icons through `spaces.names` symbol objects.
`{{#symbol}}` conditions are not supported. Use provider state conditions around
`{{symbol}}` instead.

## Formatting and output settings

The following settings still apply before `text` renders:

| Provider | Settings | Effect |
| --- | --- | --- |
| `datetime` | `format`, `dateStyle`, `timeStyle` | Format the clock value inserted by `{{value}}`. |
| `throughput` | `throughput.unit` | Choose bits or bytes for rate values and units. |
| `command`, `plugin` | `maxLength` in the provider block | Collapse whitespace and truncate the provider value before template rendering. Text added by the template is outside this limit. |
| `command`, `plugin` | `onError` in the provider block | Show an error, retain the last successful result, or hide the item. |
| `command` | `command.format`, `command.output` | Choose text/JSON parsing and stdout/combined capture. |

Command and plugin result `text` is input data exposed through `{{value}}`, not another template. Use [item widths](styling.md#item-widths) to constrain the final displayed content. Provider hide rules still hide the whole item even when a template supplies fallback text.

## Template limits

Workspace loops preserve each entry's colour and emphasis, including Spaces name icons. Throughput loops render direction icons through `{{symbol}}`. For other providers, `{{symbol}}` controls the single item icon. Existing colour and hide rules still apply. Native provider accessibility descriptions remain intact; static and clock labels use the rendered text.

There is no custom number formatter, arbitrary command JSON field lookup, or literal `{{` escape yet. Date formatting still uses the clock's `format`, `dateStyle`, and `timeStyle` fields. Command and plugin `value` retains the existing truncation and error policy. Templates affect presentation only; CLI values and subscription events retain their existing output.

Try the [Everyday bar](../examples/everyday/config.json), which uses templates for its labels:

```sh
.build/debug/sbar validate --config "$PWD/examples/everyday/config.json"
.build/debug/sbar start --config "$PWD/examples/everyday/config.json"
```

## Trying state changes

Use the Everyday configuration for a live check after building the current code.

- Open the network popup and transfer a file. Check direction icons, units, and
  separators as rates rise and return to zero. A zero rate is an available reading.
- Connect and disconnect a VPN service. With a connected-only service template,
  check that hidden services leave no leading, doubled, or trailing separator.
- Turn Bluetooth off and on, then reconnect a device. Check that old device names
  disappear while the device list is unavailable or empty.
- Switch Spaces. Confirm the active entry changes colour and separator dots keep
  the inactive colour. Try filtering entries with a conditional section.
- Try `{{symbol}}` alone and conditional symbol tags with `symbolPosition` set to
  `left` and `right`. For throughput, use `{{#transfers}}{{symbol}}{{#separator}} {{/separator}}{{/transfers}}`.
- For an item using manual refresh, change its underlying state and confirm that
  its label stays unchanged until you trigger refresh.

Automated tests exercise unavailable recovery, connection changes, refresh
snapshots, and native symbol rendering. Physical connection changes and live Space
switching still need a check on the machine running the bar.

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
| VPN/Bluetooth `labels` | State conditions inside `services`/`devices` loops; use conditions outside the loop for aggregate fallback labels |
| Workspace `format: currentTotal` | `{{index}} / {{total}}` with an unavailable/fullscreen fallback |
| Workspace `format: list` | `{{#workspaces}}{{name}}{{#separator}} {{/separator}}{{/workspaces}}` |
| Throughput `showDownload`, `showUpload`, `showValue`, `showUnits` | Choose directions and number/unit fields inside `transfers` loops |
| Workspace `showValue: false` | `"text": ""` |
| Spaces/Aerospace `labels` | Conditions on `index` or `name`, inside the loop for lists |
| Network/audio-device `labels` | Equality sections such as `{{#status=available}}Ready{{/status}}{{^status=available}}{{value}}{{/status}}` using that provider's states |

Wrap readings in an `available` section when you need an unavailable fallback. Network and audio-device `labels` maps have been removed; use equality sections instead. Bluetooth and VPN `labels` maps have also been removed; use device/service loops with state conditions. Workspace formats and label maps have been replaced by workspace fields and loops. Clock formatting and command output format remain supported. Provider symbols, tints, hide rules, and data-selection settings are unchanged.

Throughput supports symbol-aware `transfers` loops. See [throughput](providers/throughput.md) for number/unit fields and replacements for the removed `showDownload`, `showUpload`, `showValue`, and `showUnits` settings.
