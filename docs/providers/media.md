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
    "showTitle": true,
    "showArtist": true,
    "separator": " — ",
    "hideWhenPaused": false,
    "hideWhenStopped": true
  }
}
```

`source` accepts `automatic` (default), `music`, or `spotify`. Explicit selection
ignores the other player for that item; different items may select different sources.
`showTitle`, `showArtist`, and `showSymbol` default to `true`. The default separator
is ` — ` and only appears between nonempty fields. Hide title and artist for an
icon alone. Accessibility retains the source, playback state, and known metadata.

Paused playback retains track details when the notification omits them. Stopped
playback and app termination clear that player's track. A new title does not inherit
the previous artist when the artist is missing. Missing visible metadata falls
back to `Playing` or `Paused`; stopped playback shows `Stopped`. Unknown or malformed
playback state shows `Playback unavailable`, rather than being treated as paused.

`hideWhenPaused` and `hideWhenStopped` default to `false` and apply to the selected
source. Customize `symbols.playing`, `symbols.paused`, `symbols.stopped`, and
`symbols.unavailable` (defaults `play.fill`, `pause.fill`, `stop.fill`, `questionmark`).
Glyphs inherit `symbols.font` and optional `symbols.size`, with per-glyph overrides.
An item-level `symbol` overrides the state symbols; `showSymbol: false` hides it.

Startup remains notification-based: `Waiting for playback` is shown until the
selected source sends an update, even if it was already playing when the bar
started. Start or change a track to populate it. This integration does not query
current playback, control players, or display artwork.

Refresh policies snapshot both players' states together. Manual/interval items
retain their track, state symbol, and visibility until refreshed, including after
a player quits. Provider events use the default automatic selection and text.

See [common item settings](../configuration.md#items), [refresh policies](../configuration.md#refresh-policies), [styling](../styling.md), and [symbols](../symbols.md) for shared options.
