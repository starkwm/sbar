# Command line

[Documentation index](index.md)

## Start the bar

Run `sbar` without a subcommand to start the bar. `sbar start` is the explicit equivalent:

```sh
sbar [start] [--config <path>]
```

Other invocations send commands to the running process. `validate` checks a configuration file independently. Commands return a nonzero exit status on failure. Run `sbar --help` or `sbar <command> --help` for help.

Client commands connect to `~/.config/sbar/control.sock`. An instance started with `--config` creates `control.sock` beside that file. Pass `--socket <path>` after the client subcommand to target it:

```sh
sbar start --config /path/to/config.json
# In another terminal:
sbar query --socket /path/to/control.sock
```

Only one instance can own a given socket, and clients must run as the same user.

## Validate configuration

```sh
sbar validate [--config <path>]
```

Check a configuration file without starting the bar. The default path is `~/.config/sbar/config.json`. Invalid or missing files produce an error and a nonzero exit status. Validation never writes the file. See [configuration](configuration.md) for the file format.

## Query state

```sh
sbar query [--diagnostics | --displays] [--socket <path>]
```

`query` returns the running configuration as JSON. `--diagnostics` returns the configuration path, current configuration error, last action error, and up to 100 recent runtime events. `--displays` returns connected display IDs, names, and whether each is primary. The two selectors are mutually exclusive.

## Reload configuration

```sh
sbar reload [--socket <path>]
```

Reload the file immediately. Invalid configuration returns an error and retains the last valid configuration.

## Update items

```sh
sbar set <item-id> <property> <value> [--socket <path>]
```

Values are parsed as JSON when possible, otherwise as strings. For example:

```sh
sbar set clock enabled false
sbar set clock style '{"tint":"#88C0D0"}'
```

`set` changes in-memory configuration only. Supported properties are `label`, `symbol`, `enabled`, `priority`, `format`, `dateStyle`, `timeStyle`, `style`, and `popup`. Edit the config file to make changes persistent. Reload or restart discards transient changes.

## Trigger events

```sh
sbar trigger <event> [<json>] [--socket <path>]
sbar trigger refresh '{"source":"manual"}'
```

Matching item IDs or refresh event names update native snapshots or rerun command items. Plugins receive all triggers. The optional payload must be valid JSON and is included in runtime events and plugin input.

## Subscribe to events

```sh
sbar subscribe [--socket <path>]
```

Streams JSON lines for configuration changes, provider values, and triggers until interrupted. Slow subscribers are disconnected.

## Stop the bar

```sh
sbar stop [--socket <path>]
```

`stop` acknowledges the request, then shuts down the bar, stops providers and child processes, closes panels, and removes the control socket. Use `--socket` to target an instance started with a custom configuration directory.
