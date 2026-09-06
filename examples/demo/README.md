# Demo configuration

From the repository root, build and launch with this alternate configuration:

```sh
make
.build/debug/sbar --config "$PWD/examples/demo/config.json"
```

Quit any running sbar instance first. This uses a separate configuration and control socket; your normal configuration is untouched. The bar appears along the bottom of every display, above a visible Dock.

- **sbar** opens a launcher popup with application, URL, and shell actions.
- The active application follows focus; its context menu opens Activity Monitor.
- The hostname demonstrates a command with manual refresh.
- Native Spaces shows the focused Space's one-based position across displays.
- Music/Spotify playback notifications update the center media item. Start or change a track after launching.
- **Events** is a self-contained shell plugin counting its start event and runtime triggers.
- CPU and memory form an inline group. **System** opens disk, network, Wi-Fi, throughput, uptime, and a manually refreshed clock snapshot.
- Volume, battery, and date/time displays using `datetime` round out the native providers. Date and clock open Calendar; the clock context menu opens System Settings.
- Lower-priority items move into overflow when space is tight. Clock and launcher have the highest priority.

Try runtime updates in another terminal, also from the repository root:

```sh
.build/debug/sbar query --socket "$PWD/examples/demo/control.sock"
.build/debug/sbar trigger --socket "$PWD/examples/demo/control.sock" demo-refresh '{"source":"demo"}'
.build/debug/sbar set --socket "$PWD/examples/demo/control.sock" clock style '{"tint":"#A3BE8C","background":"#A3BE8C22"}'
.build/debug/sbar set --socket "$PWD/examples/demo/control.sock" media enabled false
.build/debug/sbar reload --socket "$PWD/examples/demo/control.sock"
```

The trigger reruns hostname and uptime, updates the clock snapshot, and increments the plugin counter. Runtime edits last until reload or restart; edit the config file to persist changes. `subscribe` streams runtime events until interrupted.

AeroSpace and yabai items are included with `enabled: false`. Enable the one you use; they require the corresponding window manager. Change `bar.position` to `top` to try menu-bar-edge placement, or `bar.displays` to `main` to show only on the primary display. Configuration edits reload automatically.
