# Media playback

[Documentation index](../index.md#providers)

Media tracks Music and Spotify independently using their playback notifications.
By default, it selects a playing source over paused, stopped, or unknown sources,
in that order. Among sources in the same state, the most recently received update
wins. A pause notification from one player cannot replace another playing source.

```json
{
  "id": "media",
  "type": "media",
  "media": {
    "source": "automatic",
    "hideWhenNotPlaying": true
  }
}
```

`source` accepts `automatic` (default), `music`, or `spotify`. Explicit selection
ignores the other player for that item; different items may select different sources.
The default label joins title and artist with ` — ` when both are present.
Use a top-level [text template](../text-templates.md) to choose fields and separators,
or `text: ""` for an icon alone. `showSymbol` defaults to `true`.
Accessibility retains the source, playback state, and known metadata.

Paused playback retains track details when the notification omits them. Stopped
playback and app termination clear that player's track. A new title does not inherit
the previous artist when the artist is missing. Missing visible metadata falls
back to `Playing` or `Paused`; stopped playback shows `Stopped`. Unknown or malformed
playback state shows `Playback unavailable`, rather than being treated as paused.

Set `hideWhenNotPlaying` to `true` to show the item only while the selected source
is playing. It hides paused, stopped, unknown, and initial waiting states.
`hideWhenPaused` and `hideWhenStopped` can hide those individual states instead.
All three options default to `false` and apply to the selected source; enabling
any matching option hides the item.

Customize `symbols.playing`, `symbols.paused`, `symbols.stopped`, and
`symbols.unavailable` (defaults `play.fill`, `pause.fill`, `stop.fill`, `questionmark`).
Glyphs inherit `symbols.font` and optional `symbols.size`, with per-glyph overrides.
An item-level `symbol` overrides the state symbols; `showSymbol: false` hides it.

Startup remains notification-based: by default, `Waiting for playback` is shown until the
selected source sends an update, even if it was already playing when the bar
started. With `hideWhenNotPlaying: true`, the item stays hidden until a playing
update arrives. Start or change a track to populate it. This integration does not query
current playback, control players, or display artwork.

Refresh policies snapshot both players' states together. Manual/interval items
retain their track, state symbol, and visibility until refreshed, including after
a player quits. Provider events use the default automatic selection and text.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
