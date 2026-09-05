# Floating bar

A small top bar for a notched MacBook Air, with the frontmost application and focused Space on the left, an empty center, and battery, Wi-Fi, and clock on the right. It uses the system material background and appears on the primary display.

From the repository root:

```sh
make
.build/debug/sbar validate --config "$PWD/examples/floating/config.json"
.build/debug/sbar start --config "$PWD/examples/floating/config.json"
```

Quit any running sbar instance first. This demo has its own configuration and control socket. To stop it:

```sh
.build/debug/sbar stop --socket "$PWD/examples/floating/control.sock"
```

The 6-point top and side margins match the SWM window gap and edge padding in Tom's configuration when this example was added. The bar sits beside the notch at the physical top edge; its center contains no items, and notch avoidance keeps the side content clear of the cutout. It does not reserve additional space for tiled windows or hide the system menu bar.

The 12-point corner radius is a visual approximation for the inset bar, not a measured screen radius. Apple's [2025 MacBook Air specifications](https://support.apple.com/en-us/122209) describe rounded top display corners without specifying their radius. Adjust `theme.cornerRadius` to suit your display scaling; configuration edits reload automatically.

`spaces` shows the focused Space's one-based number, rather than a list of all Spaces. Change `bar.displays` to `all` to use the demo on every display.
