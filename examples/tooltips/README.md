# Tooltip templates

[Documentation](../../docs/index.md) · [Token reference](../../docs/tooltips.md)

Build and validate from the repository root:

```sh
make build
.build/debug/sbar validate --config examples/tooltips/config.json
```

With any existing sbar instance stopped, run the example:

```sh
.build/debug/sbar start --config examples/tooltips/config.json
```

The example places a bar at the bottom of the main display. Keep another app
active and hover over the items to check multiline tooltips and hidden readings.
Click the first item to check its popup. The `No tooltip` item disables help.

To check placement and overflow, change the bar to the top edge and narrow the
available width with larger left and right margins. Items in the overflow popup
use their own tooltip templates. Empty bar regions should still pass mouse events
through to the app underneath.
