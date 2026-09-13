# Mail

[Documentation index](../index.md#providers)

A `mail` item shows Apple Mail's combined inbox unread count:

```json
{
  "id": "mail",
  "type": "mail",
  "mail": { "pollInterval": 10 }
}
```

The label is `3 unread`, including `0 unread` when the inbox has no unread
messages. The symbol is `envelope.badge` with unread mail and `envelope` otherwise.
A top-level `symbol` overrides it. Accessibility labels include `Inbox`.

The provider queries Mail immediately when enabled, then waits `mail.pollInterval`
seconds after each query before checking again. The default is 30 seconds and
the minimum is 5 seconds. The example above checks every 10 seconds.
Changing the shared interval on config reload starts a new query immediately.
Mail must already be running; sbar does not launch it. Counts reflect Mail's
local synchronisation state. This first version covers the combined inbox only,
with no account or mailbox selection and no message content access.

macOS asks for permission to automate Mail. Allow sbar in System Settings >
Privacy & Security > Automation. Depending on how sbar is launched, macOS may
attribute the request to the launching application. Permission behaviour must be
checked using the same launch method as your normal bar. Hardened-runtime builds
need the `com.apple.security.automation.apple-events` entitlement.

`Mail closed`, `Mail permission denied`, and `Mail unavailable` distinguish a
closed application, denied Automation access, and other errors such as timeouts.
These states never display a zero unread count. Failed reads retry at the normal
polling interval. Apple Events run off the main thread with a ten-second timeout.

Monitoring is shared across items and displays. The shortest interval among enabled
Mail items is used, with omitted intervals counting as 30 seconds. Event, interval,
and manual refresh settings control presentation snapshots, as with other native providers;
they do not change the Mail polling interval.

See [common item settings](../configuration.md#items),
[refresh policies](../configuration.md#refresh-policies), and [symbols](../symbols.md).
