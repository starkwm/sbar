# Date and time

[Documentation index](../index.md#providers)

`datetime` items default to the system's short time style. Use `format` for a Unicode date/time pattern:

```json
{ "id": "date", "type": "datetime", "format": "yyyy-MM-dd" }
```

For example, `dd/MM/yyyy` gives a numeric day/month/year, `EEEE, d MMMM` includes the full weekday and month names, and `MMM d 'at' HH:mm` includes the time. Patterns use the system locale and time zone; quote literal words with single quotes. Use `yyyy` for the calendar year (`YYYY` is the week-based year). A nonempty `format` overrides `dateStyle` and `timeStyle`. Omitting `format`, setting it to `null`, or using an empty string uses those styles. You can also change it at runtime with `sbar set date format '"EEEE, d MMMM"'`.

For localized formatting, `dateStyle` and `timeStyle` each accept `none`, `short`, `medium`, `long`, or `full`. They default to `none` and `short`, respectively. Set `timeStyle` to `none` for a date-only display:

```json
{ "id": "date", "type": "datetime", "dateStyle": "full", "timeStyle": "none" }
```

Both style properties can also be changed with `sbar set`.

All `datetime` items share one clock.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
