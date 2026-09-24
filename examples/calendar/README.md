# Calendar bar

A compact bar with the frontmost app, the next timed Calendar event, and a clock. The event item uses blue for an upcoming event, green while it is in progress, and red when Calendar access or reading fails. Click the event for its calendar name and end time.

From the repository root:

```sh
make build
.build/debug/sbar validate --config "$PWD/examples/calendar/config.json"
.build/debug/sbar start --config "$PWD/examples/calendar/config.json"
```

The first run asks for Calendar access. sbar needs full access to read events, but this example does not edit them. Stop another sbar instance first if it would overlap. This example uses its own configuration and control socket. Stop it with:

```sh
.build/debug/sbar stop --socket "$PWD/examples/calendar/control.sock"
```

The event item ignores all-day events and hides when no timed event starts within seven days. Change `includeAllDay` to `true` in both Calendar items to include them; use `{{value}}` for the top-level `text` if you want the built-in `All day` label. Change `timeFormat`, the `tints` and `symbols` maps, or the item's `style` to alter its appearance. See the [Calendar provider reference](../../docs/providers/calendar.md) for every option.
