# Vertical bar

A narrow bar on the left edge of the primary display. Items stay upright, with app shortcuts and Spaces at the top, a system popup in the middle, and status icons and a clock at the bottom. It uses built-in macOS symbols.

## Run

From the repository root:

```sh
make build
.build/debug/sbar validate --config "$PWD/examples/vertical/config.json"
.build/debug/sbar start --config "$PWD/examples/vertical/config.json"
```

The example has its own control socket. Stop it from another terminal with:

```sh
.build/debug/sbar stop --socket "$PWD/examples/vertical/control.sock"
```

## Customise

Edit [config.json](config.json) while the example is running. Valid changes reload automatically.

- Change `bar.position` to `right` to move the bar to the other edge.
- Change `bar.width` to adjust its width, from 20 to 96 points. `bar.height` controls horizontal bars only.
- Set `bar.displays` to `all` to show it on every display.
- Add items to `items.left`, `items.center` or `items.right` for the top, middle or bottom. Group children and Spaces entries stack in array order on both edges.
- Use short labels or `"text": ""` for icon-only items. Long labels truncate to fit. Item `width` and `minWidth` still control horizontal width.

Click the gauge for CPU, memory and disk details, or the clock for the full date. Popups open towards the middle of the display. Items inside them keep their horizontal layout. Low-priority items move into overflow when a section runs out of height.

The bar reaches the physical top edge with `bar.extendToTopEdge` enabled and `bar.margin.top` set to `0`. Set `extendToTopEdge` to `false` to start below the menu bar. The Dock still limits the bottom and sides. The bar does not reserve space for other windows. Set a left or right gap in your window manager if needed.
