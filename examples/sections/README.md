# Separate sections

A floating bar with Tokyo Night colors and separate backgrounds for the app and
spaces on the left, the date and time in the center, and system status on the right.
The center moves beside the notch on displays with a notch.

From the repository root:

```sh
swift build
.build/debug/sbar validate --config examples/sections/config.json
.build/debug/sbar start --config examples/sections/config.json
```

The whole-bar background is transparent and its shadow is disabled. Shared
section styling lives in `theme.regionStyle`; `theme.regions` changes the center
background and right corner radius. Empty sections disappear automatically.
