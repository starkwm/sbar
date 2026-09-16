# Groups, popups, and overflow

[Documentation index](index.md)

`group` items show their children in a row in horizontal bars and a column in side bars. `popup` items show their children when clicked. Any item can also show a `popup` text string. Groups nest up to eight levels. Disabling a group disables its child providers.

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

When a section runs out of space, sbar moves its lowest-priority items into an overflow popover. Larger `priority` values stay visible longer. Equal priorities hide from the end of the section. Horizontal bars measure item widths and allow flexible text to shrink. Side bars measure item heights.

A nonempty center section gets one third of the bar's length. Beside a notch, the center and right sections instead share the space to the right of the cutout. Each section clips content that exceeds its bounds. Items inside popovers keep their horizontal layout.

## Dividers and spacers

A `divider` draws a line across the bar. A `spacer` adds flexible empty space along it. Both require an `id` and `type`, like other items.

See [bar settings](configuration.md#bar-settings) for placement and [common item settings](configuration.md#items) for sections, IDs, and priority.
