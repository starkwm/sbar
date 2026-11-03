# Agent activity example

The label uses `{{working}} working · {{needsInput}} needs input · {{idle}} idle` to show counts, including zeros. Remove `text` to show only states with nonzero counts. Click the item to see the sessions in the popup.

Build and validate from the repository root:

```fish
make build
.build/debug/sbar validate --config "$PWD/examples/agent-activity/config.json"
```

Start the example bar. It uses a separate control socket:

```fish
.build/debug/sbar start --config "$PWD/examples/agent-activity/config.json"
```

In another terminal, run the simulator from the repository root. It uses macOS's built-in Bash and `uuidgen` to report two conversations:

```fish
bash examples/agent-activity/simulate.sh
.build/debug/sbar agents list --socket "$PWD/examples/agent-activity/control.sock"
```

Watch the two sessions start working, then one ask for input and the other finish. Check that the counts and tint update. Open the popup, wait for the finished row to disappear after 30 seconds, then dismiss the remaining row.

To check reloads, reload the config, then remove the agent item and reload again. Stop the example bar with its own socket:

```fish
.build/debug/sbar stop --socket "$PWD/examples/agent-activity/control.sock"
```

See [agent activity](../../docs/providers/agent-activity.md) for hook setup, supported versions, hosted agents and known limits.
