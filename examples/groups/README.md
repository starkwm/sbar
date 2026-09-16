# Groups

Volume, network, and battery symbols sit beside a clock on the main display.
The group uses a 10-point gap and sets `childStyle.horizontalPadding` to zero
to remove child padding. Each child can override this with its own `style`.

From the repository root, quit any running sbar instance, then run:

```sh
swift build
.build/debug/sbar start --config "$PWD/examples/groups/config.json"
```

Change the group's `itemSpacing` to try different gaps. It accepts 0 to 96 points
and defaults to 4 when omitted. Configuration edits reload automatically.
The theme's `itemSpacing` controls the gap between the group and the clock.

To stop the example:

```sh
.build/debug/sbar stop --socket "$PWD/examples/groups/control.sock"
```
