# Reminders

[Documentation index](../index.md#providers)

A `reminders` item reads incomplete tasks from Apple EventKit. The default label shows disjoint counts such as `3 due · 1 overdue`. The [Reminders example](../../examples/reminders/README.md) includes a summary and a popup with next-task details. sbar never edits or completes reminders.

## Lists and permission

Discover the local list IDs before selecting lists:

```fish
.build/debug/sbar reminders lists
```

This standalone command requests Reminders permission if needed and prints JSON records with `id`, `title`, `sourceId` and `sourceTitle`, sorted by account title, list title and ID. It fetches list metadata, not task contents, and does not start the bar. An empty successful result is `[]`; denied access or a read failure exits nonzero.

The first enabled Reminders item also requests permission through the **Sbar EventKit** background helper. `make build` packages that helper beside the binary; keep it there when installing. The helper is launched as a macOS app so permission does not depend on the terminal. Apple requires **full read/write Reminders access even for read-only display**. Calendar permission does not grant Reminders access. Validation never requests access. Denied or restricted permission stays visible; grant Sbar EventKit access in System Settings to recover. sbar keeps reminder data in memory and does not send it to a server.

```json
{
  "id": "tasks",
  "type": "reminders",
  "reminders": {
    "listIds": ["ID-FROM-DISCOVERY"],
    "lookaheadDays": 7,
    "includeUndated": false
  }
}
```

Omit `listIds` for all EventKit reminder lists. An explicit array must contain unique, nonblank IDs and cannot be empty. Lists with the same name remain distinct. Renaming a list preserves selection while its ID remains valid. IDs are local to this store and may change after a full sync. If any selected ID disappears, the item reports a missing list, without partial counts or automatic name matching. Run discovery again and update the configuration.

## Counts and next task

Only incomplete reminders participate. Each returned reminder ID counts once, including records from shared or read-only lists. Completed tasks are excluded. Repeating reminders use the incomplete records EventKit currently returns; sbar does not generate future occurrences.

| Field | Meaning |
| --- | --- |
| `overdueCount` | Timed deadline before now, or date-only due day before today; no historical cutoff |
| `dueTodayCount` | Due today and not already overdue |
| `upcomingCount` | Due tomorrow through `lookaheadDays` days after today, inclusive |
| `undatedCount` | No due date, only when `includeUndated: true` |
| `total` | Sum of these groups, excluding tasks beyond the horizon |

`lookaheadDays` defaults to 7 and accepts 1–30. `includeUndated` defaults to false.

At the exact timed deadline, a task is still due; immediately afterward it is overdue. Date-only tasks become overdue at the following local midnight. Date-only civil dates do not shift with timezones. Floating timed dates use the system timezone; explicitly zoned deadlines use their timezone and are classified into the current local day. Day arithmetic accounts for daylight-saving changes. Invalid nonempty due dates produce an unavailable result rather than an undated task.

The selected task is the oldest overdue task, then today's earliest remaining task, then the earliest upcoming task, then an opted-in undated task. Within a date, timed tasks precede date-only tasks. Equal deadlines sort by whitespace-normalized title, list ID and reminder ID. Priority does not change ordering. Blank titles display `Untitled reminder`.

EventKit exposes due dates, completion, priority and recurrence rules. Its documented model does not expose Reminders smart-list definitions, tags, sections or subtask relationships. sbar treats returned tasks as flat records. Its counts need not match the Reminders app's Today smart list. It does not read notes, attachments or URLs.

## Templates and appearance

Use top-level `text` for labels. For a title beside the default count:

```json
"text": "{{value}}{{#hasNext}} · {{title}}{{/hasNext}}"
```

In addition to the counts, these fields are available:

| Field | Meaning |
| --- | --- |
| `value` | Default label |
| `status` | `loading`, `overdue`, `dueToday`, `upcoming`, `undated`, `empty`, `unauthorized`, `unavailable` |
| `available` | True for successful results, including empty |
| `hasNext` | Whether a task was selected |
| `title`, `list`, `listId` | Selected task title and list metadata |
| `dueDate`, `dueTime` | Localized date and time; time is empty for date-only or undated tasks |
| `due` | Combined due date/time, or `No due date` |
| `allDay`, `hasDueDate` | Booleans about the selected task |
| `nextStatus` | Selected task's `overdue`, `dueToday`, `upcoming` or `undated` group |
| `error` | Safe diagnostic without task contents |

Selected-task strings are empty without a selected task; booleans are false. Counts are zero for successful empty results and empty strings for loading or failed results. A custom template should retain `{{value}}` or provide explicit fallback sections.

The default label is `N due · M overdue` when either count is nonzero, `N upcoming` when only upcoming work qualifies, `N undated` for an undated-only selection, or `No reminders due` for empty. Loading, denied permission and read failures have explicit labels. Status precedence follows the task selection order.

`reminders.timeFormat` accepts a nonblank DateFormatter pattern such as `HH:mm`. Omit it for the system's short time. `symbols` and `tints` accept all eight status names, following the [shared symbol](../symbols.md) and colour conventions. The default symbol is `checklist`, `exclamationmark.circle` for overdue, or `exclamationmark.triangle` for access/read failures. No tint is imposed by default.

A top-level `symbol` overrides the status symbol. `showSymbol: false` hides it; top-level `text: ""` hides the label. `hideWhenEmpty: true` hides only confirmed empty results. These options default to showing the symbol and retaining empty items.

Accessibility includes counts, the selected task's title, list and due information, and any error. Hiding the text does not conceal task details from accessibility output.

Use existing `popup` and `children` configuration for summary and next-task details. Give child Reminders items the same filters as the parent when they should describe the same selection. There are no task loops, task completion controls, app-opening actions or supported task deep links supplied by this provider.

## Refresh and lifecycle

All enabled Reminders items, including popup children and items on multiple displays, share one collector. It reads the union of selected lists, or all lists when any item omits selection. Filtering, counts and presentation remain per item.

Collection runs initially, on EventKit changes and every minute. Simultaneous changes coalesce into a follow-up read. Cached records are reclassified at deadlines and midnight. Wake, clock and timezone changes cause reclassification and refresh. Sync latency is controlled by macOS and the account provider.

Standard refresh policies apply. Without a policy, or with event refresh, items follow collected state. Interval and manual items capture the latest shared snapshot; a manual trigger does not force an EventKit query. Text, accessibility and subscription values use the same selected snapshot. Filter changes invalidate snapshots, and permission, selection or read failures clear captured task details even for manual items.

An ordinary refresh retains the previous successful display until the result arrives. Read failures replace live results with unavailable state. Removing the final item stops bar-side collection and discards cached state. The shared EventKit helper exits after roughly two idle minutes when no requests remain. Pending fetches are cancelled and stale callbacks cannot publish into a later activation.

## Apple references

- [Access requirements](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
- [Due-date components](https://developer.apple.com/documentation/eventkit/ekreminder/duedatecomponents)
- [List identifiers](https://developer.apple.com/documentation/eventkit/ekcalendar/calendaridentifier)
- [Incomplete reminder queries](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforincompletereminders(withduedatestarting:ending:calendars:))
- [Cancellation](https://developer.apple.com/documentation/eventkit/ekeventstore/cancelfetchrequest(_:))
