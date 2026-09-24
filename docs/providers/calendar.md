# Calendar

[Documentation index](../index.md#providers)

A `calendar` item shows the current or next event from the calendars macOS makes available through EventKit:

```json
{
  "id": "next-event",
  "type": "calendar",
  "calendar": {
    "lookaheadDays": 7,
    "includeAllDay": false,
    "hideWhenEmpty": true
  }
}
```

The default lookahead is seven days; the allowed range is 1–30 days. `includeAllDay` defaults to `true`. An ongoing timed event takes priority over an ongoing all-day event. Otherwise, the next event by start time is shown. The default label is the local start time and title, `Now` and title for an ongoing event, or `All day` and title for an all-day event. Untitled events display `Untitled event`.

The first active Calendar item asks for full Calendar access. The system requires this access to read events even though sbar never edits them. A denied request displays `Calendar permission denied`. Read failures display `Calendar unavailable`, and an empty selection displays `No events`. The provider checks every minute and also reacts to EventKit change notifications. Enabled items share one query, using the longest configured lookahead. Removing the last item stops monitoring. sbar does not send event data to a server.

Use a top-level text template to choose the displayed fields:

```json
{
  "id": "next-event",
  "type": "calendar",
  "text": "{{#status=upcoming}}{{startTime}} · {{title}}{{/status}}{{#status=ongoing}}Now · {{title}}{{/status}}",
  "calendar": {
    "timeFormat": "HH:mm",
    "tints": {"ongoing": "#66CC88", "unauthorized": "#FF6655"},
    "symbols": {"ongoing": "calendar.badge.clock"}
  }
}
```

`title` and `calendar` are the selected event's title and calendar name. `startTime` and `endTime` use the system's short local time unless `timeFormat` supplies a DateFormatter pattern. `minutesUntil` rounds up to the next whole minute and is zero for ongoing events. `allDay` is a boolean. `available` is true when Calendar access is granted, including an empty selection. `status` is `loading`, `upcoming`, `ongoing`, `empty`, `unauthorized`, or `unavailable`. Event fields are empty when no event is selected. `value` is the default label.

`calendar.symbols` and `calendar.tints` accept the six status names. Symbols accept SF Symbol names or font glyph objects, with optional shared `font` and `size`. The default symbols are `calendar` for loading, upcoming, and empty, `calendar.badge.clock` for ongoing, and `calendar.badge.exclamationmark` for denied access or read failures. A top-level `symbol` overrides the state symbol. Set `calendar.showSymbol: false` for text only, or top-level `text: ""` for an icon alone. `hideWhenEmpty` only hides an empty selection; permission and read failures stay visible. Standard [item styling](../styling.md), actions, and refresh policies also apply.

To keep event titles out of the bar, use a template such as `{{#status=upcoming}}{{startTime}} event{{/status}}`. The default accessibility label includes the event title, so an icon-only item does not hide it from accessibility output.
