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

## Group spacing

Set `itemSpacing` on a group to change the gap between its children. It accepts 0 to 96 points and defaults to 4. Nested groups use their own spacing. Theme and region `itemSpacing` settings control the gaps between top-level items.

Children inherit padding, width, and other styles from `theme.itemStyle`. Use the group's `childStyle` to override those defaults for all its children. A child's own `style` overrides matching fields in `childStyle`. Nested groups inherit these defaults and can set their own `childStyle`.

To keep symbols close together, remove child padding with `childStyle.horizontalPadding: 0`:

```json
{
  "id": "status",
  "type": "group",
  "itemSpacing": 2,
  "childStyle": { "horizontalPadding": 0 },
  "children": [
    {
      "id": "volume",
      "type": "volume",
      "text": ""
    },
    {
      "id": "network",
      "type": "network",
      "text": ""
    },
    {
      "id": "battery",
      "type": "battery",
      "text": ""
    }
  ]
}
```

Use the group's `style.horizontalPadding` to add space around the whole group. If the theme sets `minWidth`, set `childStyle.minWidth` to `0` to let children shrink to their content. A fixed `width` still takes precedence over `minWidth`.

## Overflow

Each region measures its items, allows flexible text to compress, and moves low-priority items into an overflow popover when space runs out. Larger `priority` values remain visible longer; equal priorities hide from the end. On displays without a notch, the center reserves one third of the bar when populated. Beside a notch, the center and right sections share the usable right-hand area. Bar content stays clipped within its own region.

## Dividers and spacers

A `divider` item draws a vertical separator. A `spacer` item adds flexible empty space. Both require an `id` and `type`, like other items.

See [bar settings](configuration.md#bar-settings) for placement and [common item settings](configuration.md#items) for sections, IDs, and priority.
