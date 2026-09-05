# Manual validation

These checks remain unperformed. Run them on a macOS desktop when ready to launch the app.

1. Run `make test`, then `make`. Launch `.build/debug/sbar` and verify there is no menu bar icon or Settings window.
2. Write a temporary configuration, then launch with `.build/debug/sbar --config /tmp/starkbar-check/config.json`. Use `.build/debug/sbar query --socket /tmp/starkbar-check/control.sock` for that instance. Quit any existing instance using the same config directory first.
3. Check top/bottom placement on primary, all, and selected displays, including a display with a negative desktop origin. Unplug/reconnect a display, change resolution, and change the primary display. Verify one panel per chosen display, top bars flush with the physical edge, content clear of the notch, and bottom bars clear of the Dock. Top placement shares the system menu-bar area.
4. Change Spaces, enter/exit fullscreen, toggle Stage Manager, and cycle windows. Verify the bar remains on intended Spaces, is excluded from cycling, and does not steal application focus.
5. Enable empty-region mouse pass-through. Click an underlying window through empty bar space, then hover/click an item and its popup. Verify overflow items remain reachable at narrow widths and high-priority items survive first.
6. Switch applications, change power source and output volume/device, change network connection, and play/pause Music or Spotify. Compare metrics with Activity Monitor. Media initially waits for a playback notification; Wi-Fi only exposes connection state.
7. Edit valid/invalid JSON externally, save by atomic replacement, delete/recreate it, and inspect `sbar query --diagnostics`. Verify invalid edits retain the prior valid layout. Test a version-1 command file and confirm loading never rewrites it.
8. Run `sbar validate --config /tmp/starkbar-check/config.json` on valid, invalid, and missing files. Check success/failure exit codes and error paths. Use `query --displays` to obtain IDs for selected-display configuration.
9. Exercise `sbar set`, `trigger`, and `subscribe`; confirm transient edits disappear on reload and the file is unchanged. Test a command timeout and a plugin that crashes or emits malformed JSON. Verify the app stays responsive and the process exits on removal/quit.
10. Sleep/wake with native, command, and plugin items enabled. Confirm provider values resume, panels reposition, no duplicate processes remain, and `sbar stop --socket /tmp/starkbar-check/control.sock` cleans up the control socket.
11. Use VoiceOver and keyboard navigation in popovers. Profile idle and active CPU/memory with one and several displays. Confirm display count does not multiply sampling or plugin processes.
12. Add a `spaces` item. Switch native Spaces, focus applications on different displays, and enter/exit fullscreen. Confirm every bar shows the same focused Space's one-based position across displays. Reorder/add/remove Spaces in Mission Control, switch Spaces, and verify the number follows the new ordering. Repeat with separate Spaces per display enabled and disabled.

Cleanup: stop the test instance through the CLI, confirm the temporary control socket is gone, and remove only `/tmp/starkbar-check` if created for these checks. Restore the normal configuration before relaunching your usual instance.
