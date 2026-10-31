# Pomodoro

[Documentation index](../index.md#providers)

A `pomodoro` item shows and controls one shared timer per sbar process. The [Pomodoro example](../../examples/pomodoro/README.md) includes a timer and a controls popup.

```json
{"id": "pomodoro", "type": "pomodoro"}
```

The timer starts ready, without counting down. Click to start, pause, or resume. Its context menu offers Start, Pause, Resume, Skip phase, and Reset cycle. An explicit `primaryAction` replaces the default toggle. A configured `popup` opens normally without toggling the timer. Native controls remain in the context menu alongside any secondary action.

## Timing and transitions

```json
{
  "id": "pomodoro",
  "type": "pomodoro",
  "pomodoro": {
    "focusMinutes": 25,
    "shortBreakMinutes": 5,
    "longBreakMinutes": 15,
    "cyclesBeforeLongBreak": 4,
    "autoStart": false,
    "sound": false
  }
}
```

These are the defaults. Durations accept whole minutes from 1 to 180; the long-break interval accepts 1 to 12 completed focus sessions.

| Event | Result |
| --- | --- |
| Start | Start a ready phase; otherwise do nothing |
| Pause | Freeze a running phase; otherwise do nothing |
| Resume | Continue a paused phase; otherwise do nothing |
| Toggle | Start, pause, or resume according to current status |
| Focus expires | Credit one focus session and prepare a short break, or a long break when the configured count is reached |
| Short break expires | Prepare focus |
| Long break expires | Clear the completed count and prepare focus |
| Skip | Prepare the next phase, ready, without crediting a focus session or sounding an alert |
| Reset | Apply configured timing rules and return to full focus, ready, with zero completed sessions |

Skipping a long break clears the completed count. Skipping focus normally prepares a short break because skipped focus sessions do not count toward a long break. Controls reconcile an overdue phase before applying the requested operation.

By default, each next phase waits for Start. `autoStart: true` starts a full successor phase when expiry is processed. Delayed callbacks complete at most one phase, without inventing completed unattended cycles.

Sleep counts toward the running phase. If it expires during sleep, wake completes that phase once and leaves the successor ready, even with automatic transitions enabled. A shorter sleep resumes the remaining countdown. A paused timer stays paused. Timing uses a continuous clock, so system date, timezone, and daylight-saving changes do not affect it.

## Sharing and reload

Enabled items, popup children, overflow items, and all displays share the same timer. Closing a popup does not stop it. Shared settings come from explicit values across active pomodoro items; omitted settings inherit the shared value or the default. Conflicting explicit values are configuration errors. Symbols, tints, templates, and `showSymbol` belong to each item independently.

Reload preserves the phase, status, remaining time, and completed count. Changed durations or cycle counts wait until Reset, even across subsequent cycles. Sound and automatic-transition changes apply immediately. `sbar pomodoro status` exposes `activeTiming`, `configuredTiming`, and `resetRequired` to distinguish these settings. An invalid reload retains the previous configuration and session.

Disabling or removing the last active item discards the session. Re-adding an item or restarting sbar begins a fresh ready focus phase. No timer state is written to disk.

## Presentation and templates

The default label is `Focus 25:00 · Ready`, `Focus 24:59`, or `Focus 12:30 · Paused`, with corresponding break labels. Remaining seconds round up and never become negative. Digits use the existing monospaced presentation.

| Field | Value |
| --- | --- |
| `value` | Default label |
| `phase` | `focus`, `shortBreak`, or `longBreak` |
| `phaseLabel` | Focus, Short break, or Long break |
| `status` | `ready`, `running`, or `paused` |
| `remaining` | Remaining time as minutes and seconds |
| `remainingSeconds` | Remaining seconds, rounded up |
| `durationSeconds` | Full duration under the active timing rules |
| `progress` | Integer elapsed percentage, 0–100 |
| `completedSessions` | Completed focus sessions in the current cycle |
| `cyclesBeforeLongBreak` | Active cycle target |

```json
{
  "id": "progress",
  "type": "pomodoro",
  "text": "{{phaseLabel}} {{remaining}} · {{progress}}%{{#status=paused}} · Paused{{/status}}",
  "pomodoro": {
    "tints": {"focus": "#EBCB8B", "shortBreak": "#A3BE8C", "longBreak": "#81A1C1", "paused": "#D08770"}
  }
}
```

`symbols` and `tints` accept `focus`, `shortBreak`, `longBreak`, and `paused`. A configured paused value overrides the phase value. The default symbols are `timer`, `cup.and.saucer`, `moon.zzz`, and `pause.circle` while paused. Symbols support SF Symbols or font glyphs with shared `font` and `size`. No tint is forced by default. A top-level `symbol` overrides the provider symbol; `showSymbol: false` hides it. Top-level `text: ""` hides the text.

Accessibility labels and tooltips retain the phase, status, remaining time, and completed-session count even when display text is customized. The timer does not request per-second accessibility announcements.

The default refresh behavior updates about once per second while running. Existing event, interval, and manual refresh policies still apply to presentation snapshots. Frozen snapshots do not pause the timer. Text and accessibility presentation use the same snapshot; context-menu controls and CLI commands always use live state. Subscriptions receive template-independent default labels.

## Sound and controls

`sound: true` plays the system Glass sound once on natural completion, including a completion processed on wake. Reset, Skip, and reload are silent. Sound failure does not stop the timer; inspect `pomodoroSoundError` with `sbar query --diagnostics`. There are no Notification Center prompts, notifications, custom sound paths, progress rings, or history storage.

```fish
sbar pomodoro status
sbar pomodoro start
sbar pomodoro pause
sbar pomodoro resume
sbar pomodoro toggle
sbar pomodoro reset
sbar pomodoro skip
```

All commands accept `--socket`. Responses contain the current structured snapshot and do not depend on display templates. Commands fail when no pomodoro item is active. See [CLI reference](../cli.md#pomodoro-timer).

Native actions can also be attached to ordinary items, including popup buttons:

```json
{"id": "reset-timer", "type": "text", "text": "Reset cycle", "primaryAction": {"kind": "pomodoro", "value": "reset"}}
```

Action values are `start`, `pause`, `resume`, `toggle`, `reset`, and `skip`. They control the timer directly without a shell or a separate socket connection.
