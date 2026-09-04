# Manual validation

These checks remain unperformed. Run them on a macOS desktop when ready to launch the app.

1. Run `make test`, then `make`. Launch `.build/debug/sbar` and open Settings from its menu extra.
2. Save a temporary configuration, then launch with `.build/debug/sbar --config /tmp/starkbar-check/config.json`. Use `.build/debug/sbarctl --socket /tmp/starkbar-check/control.sock query` for that instance. Quit any existing instance using the same config directory first.
3. Check top/bottom placement on primary, all, and selected displays, including a display with a negative desktop origin. Unplug/reconnect a display, change resolution, and change the primary display. Verify one panel per chosen display, top bars flush with the physical edge, content clear of the notch, and bottom bars clear of the Dock. Top placement shares the system menu-bar area.
4. Change Spaces, enter/exit fullscreen, toggle Stage Manager, and cycle windows. Verify the bar remains on intended Spaces, is excluded from cycling, and does not steal application focus.
5. Enable empty-region mouse pass-through. Click an underlying window through empty bar space, then hover/click an item and its popup. Verify overflow items remain reachable at narrow widths and high-priority items survive first.
6. Switch applications, change power source and output volume/device, change network connection, and play/pause Music or Spotify. Compare metrics with Activity Monitor. Media initially waits for a playback notification; Wi-Fi only exposes connection state.
7. Edit valid/invalid JSON externally, save by atomic replacement, delete/recreate it, and inspect Settings diagnostics. Verify invalid edits retain the prior valid layout. Test a version-1 command file and confirm Save creates version 2 plus a verbatim backup.
8. Move/add/remove items in Settings, edit styles/actions, import/export, and leave a dirty draft while changing the file externally. Verify the conflict notice, preview, keyboard Save, validation errors, and reload behavior.
9. Exercise `sbarctl set`, `trigger`, and `subscribe`; confirm transient edits persist only after Settings Save. Test a command timeout and a plugin that crashes or emits malformed JSON. Verify the app stays responsive and the process exits on removal/quit.
10. Sleep/wake with native, command, and plugin items enabled. Confirm provider values resume, panels reposition, no duplicate processes remain, and quitting cleans up the control socket.
11. Use VoiceOver and keyboard navigation in Settings and popovers. Profile idle and active CPU/memory with one and several displays. Confirm display count does not multiply sampling or plugin processes.

Cleanup: quit the test instance, confirm the temporary control socket is gone, and remove only `/tmp/starkbar-check` if created for these checks. Restore the normal configuration before relaunching your usual instance.
