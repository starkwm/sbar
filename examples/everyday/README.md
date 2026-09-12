# Everyday bar

A dark, rounded bar for daily use, with a cyan launcher, a centered date, and compact system indicators. It floats 10 points above the bottom work area on every display, clearing a visible Dock. Popovers follow the system appearance so their text stays readable in light and dark mode.

## Run

From the repository root:

```sh
make build
.build/debug/sbar validate --config "$PWD/examples/everyday/config.json"
.build/debug/sbar start --config "$PWD/examples/everyday/config.json"
```

Stop your usual sbar instance first if it would overlap. This example has its own configuration and control socket. To stop it from another terminal, run this from the repository root:

```sh
.build/debug/sbar stop --socket "$PWD/examples/everyday/control.sock"
```

## Use

| Item | What it does |
| --- | --- |
| Desktop | Opens Finder, Downloads, Terminal, Safari, or System Settings. |
| Spaces | Shows the current Space and total for that display. Click to open Mission Control. |
| Active app | Follows focus and shows the application's own icon. |
| Date | Opens Calendar. |
| CPU | Shows smoothed usage. Click for CPU, memory, free disk space, and an Activity Monitor shortcut. |
| Network | Follows the active connection. Click for connection type, VPN names and status, and download/upload rates. |
| VPN | Shows a green shield when connected and a different color during transitions or read failures. Hides when disconnected. Click to open System Settings. |
| Sound | Opens volume, mute controls, default output and microphone names, and Music/Spotify track information. |
| Battery | Shows charge with low-battery and charging colors. Click to open System Settings. Desktops show AC power. |
| Clock | Opens the full date and shortcuts to Calendar and Reminders. |

The sound buttons adjust volume in steps of 10 percentage points, clamped to 0–100, or toggle mute. They use macOS's built-in AppleScript commands. Fixed-volume outputs still need their own hardware or application controls. Device names describe the current defaults; selecting a device happens in System Settings.

Music and Spotify send track updates after playback starts or changes. Until the first notification, the sound popover shows `Waiting for playback`. Network status describes the active connection, not the Wi-Fi name or signal strength. Transfer rates total non-loopback interfaces, including tunnels. VPN status covers services registered with macOS. See the [provider references](../../docs/index.md#providers) for details.

## Customize

Edit [config.json](config.json) while the bar is running; valid changes reload automatically. The example needs no extra fonts, window manager, scripts, or plugin installation.

- Set `bar.displays` to `main` for the primary display only.
- Adjust `bar.margin` and `theme.cornerRadius` to match your window gaps.
- Change launcher application bundle IDs to use your preferred apps.
- Move `media` from the sound popover into `items.center` to put track information in the middle instead of the date.
- Change the clock's `format` to `h:mm a` for a 12-hour clock.
- Set larger item priorities to keep them visible longer. The launcher and clock have the highest priority; lower-priority items move into overflow when space is tight.

The bottom bar does not reserve space for windows. Add a matching bottom gap in your window manager if you want windows to stop above it.

Inspect the example's diagnostics without targeting your normal bar:

```sh
.build/debug/sbar query --diagnostics --socket "$PWD/examples/everyday/control.sock"
```
