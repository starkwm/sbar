# Actions

[Documentation index](index.md)

Items accept `primaryAction` and `secondaryAction` objects with `kind` (`command`, `url`, or `application`) and `value`. Primary actions run on click; secondary actions appear in the context menu. URL actions allow HTTP, HTTPS, and mailto. Application values are bundle IDs or paths; `${NAME}` and `~` expand in URL/application paths. Shell actions use `/bin/sh -c` and inherit the environment.

```json
{
  "id": "settings",
  "type": "text",
  "label": "Settings",
  "primaryAction": { "kind": "application", "value": "com.apple.systempreferences" },
  "secondaryAction": { "kind": "command", "value": "open -a 'Activity Monitor'" }
}
```

See [shell command items](providers/command.md) to display command output, and [groups and popups](layout.md) to build menus.
