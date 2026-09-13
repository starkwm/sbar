# Shell commands

[Documentation index](../index.md#providers)

A `command` item requires a nonblank `command.script`. Scripts run through `/bin/sh -c`, inherit sbar's environment, and run once at startup. Add `refresh: {"mode":"interval", "seconds":10, "event":"refresh"}` to rerun periodically or on that trigger. Item-ID triggers also rerun commands without a refresh configuration.

```json
{
  "id": "hostname",
  "type": "command",
  "symbol": "desktopcomputer",
  "command": {"script": "hostname -s", "timeout": 5, "maxLength": 80},
  "refresh": {"mode": "interval", "seconds": 60, "event": "refresh"}
}
```

`command.timeout` accepts 0.1–60 seconds and defaults to five seconds. Captured output is limited to 64 KB, and the process group is terminated on timeout, cancellation, or completion. Rapid triggers coalesce for 50 milliseconds and replace a running command. Interval delays begin after completion; a trigger restarts that schedule. Changes to scripts, execution options, or refresh settings rerun the command; appearance changes do not.

`command.format` is `"text"` (default) or `"json"`. Text mode captures combined stdout/stderr by default; set `command.output:"stdout"` to exclude diagnostics. JSON mode always uses stdout and rejects an explicit `output:"combined"`. Excluded stderr is discarded. Display text collapses whitespace and line breaks into spaces, and is truncated with an ellipsis to `command.maxLength` characters (default 256, range 1–4096). Empty successful text is allowed. This limit applies to `{{value}}` before the item's [text template](../text-templates.md) renders, so added template text is not included in the limit.

The item's top-level `text` can format output, for example `"text": "Updates: {{value}}"`. The JSON result's `text` supplies provider data; it is not evaluated as a template. Templates also expose `status` and `error`.

JSON commands emit one object with required string `text` and optional `symbol`, `tint`, and `hidden` fields:

```json
{"text":"3 updates","symbol":"shippingbox.fill","tint":"#FFCC00","hidden":false}
```

Enable this with `"command":{"script":"/path/to/check-updates","format":"json"}`. Symbols accept SF Symbol names or glyph objects such as `{"glyph":"X","font":"Menlo","size":14}`. Tints accept `#RRGGBB` or `#RRGGBBAA`. Invalid JSON or invalid field values are failures. Output is treated as data and is never executed.

`command.symbols.running`, `.success`, and `.failure` supply state-specific symbols, with shared `symbols.font` and `.size` for custom glyphs. Symbol precedence is the top-level item `symbol`, then the configured state symbol, then the JSON result symbol. No symbol is added by default. `command.tints.running`, `.success`, and `.failure` override a result's tint; otherwise item styling applies. Top-level `text: ""` hides text. `command.showSymbol:false` hides symbols; it defaults to `true`.

`command.onError` supports `"show"` (default, displays the error), `"keepLast"` (retains the last successful result), or `"hide"` (hides the item). Without a prior success, `keepLast` displays the error. While rerunning, the previous successful result stays visible with any configured running appearance; before the first result, the value is `…`. A retained result keeps its JSON symbol, tint, and visibility, subject to configured state overrides. Nonzero exits, timeouts, output-limit failures, and invalid JSON all follow the selected error policy.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
