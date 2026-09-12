# Frontmost application

[Documentation index](../index.md#providers)

A `frontApplication` item shows the name of the application that owns the native menu bar and observes changes to that ownership. Temporary launchers such as Conjuror keep the underlying application's name and icon, including when a launcher hides its window without giving up keyboard focus.

Set `frontApplication.showIcon` to show the active application's native colour icon:

```json
{ "id": "app", "type": "frontApplication", "frontApplication": { "showIcon": true } }
```

This defaults to `false`. The icon replaces the item's `symbol`; if macOS provides no icon,
the configured symbol is used as a fallback. Its size follows the resolved item font size (`style.fontSize`, then the theme font size).
The icon and application name follow the item's refresh policy together. A fixed `label`
still overrides the name; use `"label": ""` for an icon-only item.

Set the item's `"symbolPosition": "right"` to put the icon after the name. The default is
`"left"`. This also controls the fallback symbol when no application icon is available.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
