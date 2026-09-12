# Everyday bar

A dark bar for daily use, with compact system indicators and the [Tokyo Night](https://github.com/folke/tokyonight.nvim) Night palette. It sits at the top of every display with a soft shadow below it. Popovers follow the system appearance so their text stays readable in light and dark mode.

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
| Spaces | Lists Spaces on each display, with the active Space bold and blue and inactive Spaces muted. |
| Active app | Follows focus and shows the application's own icon. |
| Media | Shows Music/Spotify playback after the active app in orange. Only visible while playing. |
| Date | Opens Calendar. |
| Memory | Shows used memory as a percentage. Click to open Activity Monitor. |
| CPU | Shows smoothed usage. Click for CPU, memory, free disk space, and an Activity Monitor shortcut. |
| Network | Follows the active connection. Click for connection type, VPN names and status, and download/upload rates. |
| VPN | Shows a green shield when connected and a different color during transitions or read failures. Hides when disconnected. Click to open System Settings. |
| Sound | Opens volume, mute controls, and default output and microphone names. |
| Battery | Shows charge with low-battery and charging colors. Click to open System Settings. Desktops show AC power. |
| Clock | Opens the full date and shortcuts to Calendar and Reminders. |

The sound buttons adjust volume in steps of 10 percentage points, clamped to 0–100, or toggle mute. They use macOS's built-in AppleScript commands. Fixed-volume outputs still need their own hardware or application controls. Device names describe the current defaults; selecting a device happens in System Settings.

Music and Spotify send track updates after playback starts or changes. The media item stays hidden until a playing notification arrives, and hides again when playback pauses, stops, or becomes unavailable. Network status describes the active connection, not the Wi-Fi name or signal strength. Transfer rates total non-loopback interfaces, including tunnels. VPN status covers services registered with macOS. See the [provider references](../../docs/index.md#providers) for details.

## Customize

Edit [config.json](config.json) while the bar is running; valid changes reload automatically. The example needs no extra fonts, window manager, scripts, or plugin installation.

The palette uses blue for Spaces, memory, and the clock, purple for CPU, orange for media, cyan for network, and teal for sound. Green marks connected VPN and charging states, amber marks warnings, orange marks a disconnecting VPN, and red marks errors or low battery. The bar uses Night's `#1A1B26` background with slight transparency, with `#292E42` backgrounds behind memory, CPU, and the clock.

- Set `bar.displays` to `main` for the primary display only.
- Adjust `bar.margin` and `theme.cornerRadius` to match your window gaps.
- Set `bar.shadow` to `false` for a flat appearance.
- Move `media` from `items.left` into the empty `items.center` section to put track information in the middle.
- Edit an item's [`text` template](../../docs/text-templates.md) to change its label. CPU and memory use percentage values, media adds a separator only when both title and artist are present, and `"text": ""` keeps VPN, network, and sound icon-only.
- Change the clock's `format` to `h:mm a` for a 12-hour clock.
- Set an item's `"symbolPosition": "right"` to put its symbol or application icon after its text. Omitted settings default to `"left"`. In the throughput item, each arrow moves after its own rate and download still precedes upload.
- Set larger item priorities to keep them visible longer. The clock has the highest priority; lower-priority items move into overflow when space is tight.

The bar does not reserve space for windows or hide the system menu bar. Adjust your window manager's top gap and the bar's top margin to leave enough room for the menu bar or notch on your display.

Inspect the example's diagnostics without targeting your normal bar:

```sh
.build/debug/sbar query --diagnostics --socket "$PWD/examples/everyday/control.sock"
```
