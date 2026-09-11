# Audio devices

[Documentation index](../index.md#providers)

An `audioDevice` item shows the current default output device name. Set
`audioDevice.device` to `input` to show the default microphone instead. Use two
items to display both:

```json
[
  { "id": "speakers", "type": "audioDevice" },
  {
    "id": "microphone",
    "type": "audioDevice",
    "audioDevice": { "device": "input" }
  }
]
```

`device` accepts `output` and `input`, defaulting to `output`. Available devices
show their names, such as `Studio Display Speakers` or `USB Microphone`. A missing
device shows `No output` or `No input`; a failed read shows `Output unavailable`
or `Input unavailable`. Blank names use `Unnamed device`.

`audioDevice.labels` and `audioDevice.tints` accept `available`, `disconnected`,
and `unavailable`. `labels.available` replaces the device name with a fixed label.
`showLabel:false` displays an icon only, and `showSymbol:false` hides the icon.
Both options default to `true`. Accessibility labels retain the device name and
whether it is the input or output. `hideWhenDisconnected:true` hides a missing
device while keeping read errors visible; it defaults to `false`.

`audioDevice.symbols` accepts `output`, `input`, `disconnected`, and `unavailable`,
with [font and glyph support](../symbols.md). Available outputs use
`speaker.wave.2.fill`; inputs use `mic.fill`. Missing outputs use `speaker.slash`
and missing inputs use `mic.slash`. Read errors use `exclamationmark.triangle`.
A top-level item `symbol` overrides these symbols.

The provider uses Core Audio metadata and notifications for default device
changes, renames, device removal, and audio service restarts. Monitoring starts
only while an audio device item is active and is shared across items and displays.
Unavailable reads retry every two seconds. Event items follow changes; interval
and manual items capture snapshots using the same refresh rules as other native
providers.

These are the macOS default input and normal output. Applications can choose
different devices, and macOS has a separate output for alerts. Reading the names
does not record audio or change audio settings. The [volume provider](volume.md) supplies
output volume and mute state.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
