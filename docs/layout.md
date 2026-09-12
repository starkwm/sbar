# Groups, popups, and overflow

[Documentation index](index.md)

`group` items render `children` inline. `popup` items show `children` when clicked; any item can also have a `popup` text string. Groups nest up to eight levels. Disabling a group disables its child providers.

```json
{
  "id": "system",
  "type": "popup",
  "children": [
    {
      "id": "cpu",
      "type": "cpu"
    },
    {
      "id": "memory",
      "type": "memory"
    }
  ],
  "text": "System"
}
```

## Overflow

Each region measures its items, allows flexible text to compress, and moves low-priority items into an overflow popover when space runs out. Larger `priority` values remain visible longer; equal priorities hide from the end. On displays without a notch, the center reserves one third of the bar when populated. Beside a notch, the center and right sections share the usable right-hand area. Bar content stays clipped within its own region.

## Dividers and spacers

A `divider` item draws a vertical separator. A `spacer` item adds flexible empty space. Both require an `id` and `type`, like other items.

See [bar settings](configuration.md#bar-settings) for placement and [common item settings](configuration.md#items) for sections, IDs, and priority.
