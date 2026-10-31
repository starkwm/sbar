# Pomodoro bar

A shared focus timer with a countdown, phase tints, and a controls popup. The popup's timer mirrors the main item without duplicating timing configuration. No external setup or permissions are needed.

From the repository root, in fish:

```fish
make build
.build/debug/sbar validate --config "$PWD/examples/pomodoro/config.json"
.build/debug/sbar start --config "$PWD/examples/pomodoro/config.json"
```

Start launches a bar. Avoid overlapping another bar during manual testing. This example uses its own configuration and control socket. In another terminal:

```fish
.build/debug/sbar pomodoro status --socket "$PWD/examples/pomodoro/control.sock"
.build/debug/sbar pomodoro toggle --socket "$PWD/examples/pomodoro/control.sock"
.build/debug/sbar stop --socket "$PWD/examples/pomodoro/control.sock"
```

Click the countdown to start, pause, or resume. Right-click for explicit controls, Skip, and Reset. The Controls popup has native action buttons and a progress summary.

For a short manual test, change all three durations to one minute and `cyclesBeforeLongBreak` to two, then Reset. Confirm two completed focus phases lead to a long break. Skip must not credit focus; Reset returns to ready focus. Enable `autoStart` and verify automatic advancement while awake. Sleep through an expiry and verify that wake leaves the next phase ready. Enable `sound` to check one Glass sound per completion.

Reload while running and paused, then change a duration and inspect `resetRequired` before Reset. Restart should discard the session. Set `displays` to `all` to check mirroring. Check popup/overflow interactions, left/right bar placement, VoiceOver labels, and that custom templates do not change CLI data. Actual audio output and macOS sleep/accessibility behavior require manual verification.

See [provider reference](../../docs/providers/pomodoro.md) for defaults and continuity rules.
