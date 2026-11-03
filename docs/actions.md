# Actions

[Documentation index](index.md)

Items accept `primaryAction` and `secondaryAction` objects with `kind` (`command`, `url`, `application`, or `pomodoro`) and `value`. Primary actions run on click; secondary actions appear in the context menu. URL actions allow HTTP, HTTPS, and mailto. Application values are bundle IDs or paths; `${NAME}` and `~` expand in URL/application paths. Shell actions use `/bin/sh -c` and inherit the environment.

```json
{
  "id": "settings",
  "type": "text",
  "primaryAction": {
    "kind": "application",
    "value": "com.apple.systempreferences"
  },
  "secondaryAction": {
    "kind": "command",
    "value": "open -a 'Activity Monitor'"
  },
  "text": "Settings"
}
```

See [shell command items](providers/command.md) to display command output, and [groups and popups](layout.md) to build menus.

`pomodoro` actions directly control the shared native timer. Values are `start`, `pause`, `resume`, `toggle`, `reset`, and `skip`. They work on ordinary items and popup children; no shell process is started. See [Pomodoro](providers/pomodoro.md).

You can dismiss sessions from the agent activity popup. Rows do not run shell commands or open conversations.
