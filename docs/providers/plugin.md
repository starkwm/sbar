# Process plugins

[Documentation index](../index.md#providers)

A `plugin` item uses `plugin: {"executable":"/absolute/path/to/provider", "arguments":[], "restart":true}`. `${NAME}` and `~` expand in the executable path. The executable runs directly with its arguments and inherits sbar's environment. There is no default execution timeout: plugins are long-running streams.

The provider receives newline-delimited JSON on stdin: `{"version":1,"event":"start"}` first for every new process, followed by runtime trigger events with an optional `value`. It emits one JSON object per line on stdout. Existing `{"text":"display text"}` messages continue to work; optional fields support dynamic appearance:

```json
{"text":"3 updates","symbol":"shippingbox.fill","tint":"#FFCC00","hidden":false}
```

`text` is required. `symbol` accepts an SF Symbol name or a glyph object such as `{"glyph":"X","font":"Menlo","size":14}`. `tint` accepts `#RRGGBB` or `#RRGGBBAA`, and `hidden` is a boolean. Every message replaces the previous result, so omitted optional fields reset their result-level values. stderr is discarded. Flush stdout after each update and terminate every message with a newline.

`plugin.symbols.running`, `.success`, and `.failure` supply state-specific symbols, with shared `symbols.font` and `.size` for custom glyphs. A top-level item `symbol` overrides the state symbol, which overrides the result symbol. `plugin.tints.running`, `.success`, and `.failure` override result tints; unspecified colors inherit the item style. Top-level `text: ""` hides text. `showSymbol:false` hides symbols; it defaults to `true`. Display text collapses whitespace to a single line and is limited by `plugin.maxLength` (default 4096, range 1–4096), with an ellipsis when truncated.

`plugin.onError` is `"show"` (default), `"keepLast"` (retain the last successful result), or `"hide"`. Without a prior result, `keepLast` displays the error. A new process initially uses running appearance with the previous successful result, or `…` if none exists. Valid output uses success appearance; launch, protocol, and nonzero-exit failures use failure appearance. Retained results keep their symbol, tint, and visibility, subject to state overrides. A clean one-shot exit retains its last result.

Each JSON line is limited to 64 KB excluding its terminating newline. Malformed, oversized, or unterminated messages stop the process with an explicit error. Bursts coalesce to the latest result, including a bounded single-result delivery buffer. The input mailbox holds up to 32 events and drops new events if full. Each restart creates a fresh mailbox with `start` first; queued events from the previous process are discarded, and triggers during restart backoff or after a one-shot exit are dropped.

Automatic restarts back off from one to 30 seconds. A run lasting at least 30 seconds that emitted valid output resets the delay to one second. Set `restart:false` for one-shot providers. Only plugins whose executable, arguments, or restart setting changes are restarted on reload; appearance changes preserve the process. Removing/disabling a plugin or shutting down terminates its process group. Updates from an obsolete process cannot overwrite its replacement or failure state.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
