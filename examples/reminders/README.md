# Reminders bar

A counts-only bar item with a popup showing counts and the next task's title, list and due date. It reads all lists by default, excludes undated tasks and includes seven upcoming calendar days.

From the repository root:

```fish
make build
.build/debug/sbar validate --config "$PWD/examples/reminders/config.json"
.build/debug/sbar reminders lists
.build/debug/sbar start --config "$PWD/examples/reminders/config.json"
```

`make build` also packages `Sbar EventKit.app` beside the executable. Discovery or the first enabled item launches that background helper and requests full Reminders permission under the name **Sbar EventKit**. Run the same commands from Terminal or Rex; no terminal-specific permission setup should be needed. Apple requires read/write authorization for reading, but sbar never edits reminders. Discovery prints list metadata only; starting the example reads tasks. Stop another bar first if it would overlap. This example uses its own configuration-relative control socket.

```fish
.build/debug/sbar stop --socket "$PWD/examples/reminders/control.sock"
```

To select lists, copy the discovery IDs into `reminders.listIds` on all three Reminders items. Keep `lookaheadDays` and `includeUndated` consistent across those items too. For a title in the bar, set the parent item's `text` to:

```json
"{{value}}{{#hasNext}} · {{title}}{{/hasNext}}"
```

See the [provider reference](../../docs/providers/reminders.md) for semantics, limitations, styling and refresh behavior.

## Manual verification

Use disposable tasks in a chosen test list:

- From both Terminal and Rex, grant or deny the first prompt and verify it names Sbar EventKit. Later revoke and regrant that helper's access in System Settings.
- Compare a timed task before and after its deadline, a date-only task across midnight, an undated task with the option off/on, and a completed task.
- Complete a repeating task in Reminders itself and check the next fetched record. sbar supplies no write controls.
- Rename a list, remove a selected list, and rediscover IDs. Verify that a missing selection never silently becomes all lists.
- Edit a task with the popup open, wake the Mac and reload the configuration. Check counts and details stay consistent.
- Add another item with different selected lists and a manual refresh policy. Trigger its item ID and verify it captures the latest collected state.
- Remove all Reminders items and verify monitoring stops. No other provider should reset.

Build and synthetic tests do not verify macOS permission attribution, account sync, recurring-task behavior or live notifications.
