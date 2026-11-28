# Changelog

Every successful push builds a versioned GitHub release named `v0.1.<workflow run number>`. The `latest` release is kept up to date and always serves the same single-file build at:

https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Use the [releases page](https://github.com/veroteknic/the-useless-fuck/releases) for the complete version-by-version history. Each versioned release also includes a generated `changelog.txt` asset.

## 2026-11-28 (meter look)

- Make the left-edge mood meter a bigger, chunkier vertical gauge with a wide bar, thick frame, and short tier label.
- Change the fill to a top-anchored drain: full red when rambunctious, draining downward and cooling to green as Jeremy calms down.
- Smooth the color between green, yellow, and red instead of switching in hard steps.

## 2026-11-28 (mood scale)

- Move the mood meter out of Jeremy's pet window into its own borderless, no-focus, fully click-through overlay pinned to the left edge of his current monitor.
- Make the meter vertical: it fills upward, with calm green at the bottom and rambunctious red at the top.
- Invert mood escalation: a higher reading now means more rambunctious. `curious` unlocks bolder cursor/tab behaviour and `rambunctious` unlocks dramatic close.
- Idle time now nudges the effective rambunctiousness upward instead of lowering a bad-mood threshold.
- Rename mood tiers to `sleepy`, `calm`, `meh`, `curious`, and `rambunctious`; stubborn flail also scales with the higher-is-bolder reading.

## 2026-11-28

- Move autonomous chatter timing, cursor timing, and weighted mischief choices into one director-ticked `AutonomyBehavior`; `main.gd` remains the action/input/window adapter.
- Add an always-visible pixel mood bar with a menu readout and a toggle to hide it.
- Gate stronger cursor/tab behaviour on grumpy mood and dramatic close on annoyed mood; idle time lowers the effective threshold without changing the persisted value.
- Add personality-weighted autonomous choices with cooldowns, repetition damping, bounded history, and interruption checks.
- Add a restorable dramatic close: browser tabs use `Ctrl+W` then `Ctrl+Shift+T`; non-browser windows require an explicit local allowlist, graceful `CloseMainWindow()`, and command-line relaunch.
- Denylist essential system, terminal, and Jeremy windows; never kill a process.
- Capture the foreground window before opening the action menu so menu buttons target the window the human was using.
- Add menu controls for dramatic close, non-browser close permission, mood meter, and the new status/timer diagnostics.
- Preserve pause, mischief, intensity, activity-frequency, dialogue-frequency, and per-gag disable controls.

## 2026-11-27

- Add a behaviour director skeleton as the single request/status authority for future autonomous behaviours.
- Add one canonical state readout used by the action/status menu.
- Add a drag-release watchdog so a lost mouse-up cannot leave Jeremy stuck.
- Stop cursor cooldowns being consumed by rejected steal/chase attempts.
- Validate dialogue and menu calls before dispatch, and keep speech latches from getting trapped during tab eating.
- Aim cursor grabs directly at Jeremy's face instead of his body centre.
- Only trigger cursor grabs when the pointer actually intersects Jeremy's hitbox.
- Make the pointer helper DPI-aware so grabs land on the face instead of down/right on scaled displays.
- Use per-monitor ground and wall bounds so Jeremy does not fall off a shorter secondary display.
- Add a persistent mood meter that reacts to drags, cursor grabs, eaten tabs, and read notes.
- Add a brief, non-blocking stubborn flail when Jeremy is dragged.
- Add note-read reactions that only close unedited Jeremy notes.
- Add optional user-supplied note lines, dialogue lines, and image pop-ins from `user://`, with no bundled or copied content.
- Add pause, mischief, gag, content, and frequency controls to the right-click menu.
- Correct the animation documentation: `jumping` exists; `eating` remains optional.
- Switch Jeremy's speech bubble, menu, and tab gag to an embedded Silkscreen pixel font with crisp, unantialiased rendering.
- Move walk/jump/fall into one director-ticked LocomotionBehavior; main.gd is now the input/window/drawing adapter for locomotion.

## 2026-11-27

- Open Jeremy's notes in real Windows Notepad windows instead of custom sticky-note windows.
- Keep Notepad from stealing keyboard focus from the browser.
- Add top padding to notes, move them away from the top screen edge, and make the windows a bit smaller.
- Make real Notepad launches asynchronous so opening a note cannot freeze Jeremy.

## 2026-11-27

- Add edge behaviors: wall hangs, slides, kick-offs, and ceiling peeks.
- Add time-aware idle chatter for mornings, afternoons, evenings, nights, Mondays, Fridays, and weekends.
- Add Jeremy-authored sticky notes.
- Add tab-eating escalation with crumbs, daily counts, and snack dialogue.
- Add cursor stealing by middle-click, occasional automatic cursor tugs, and autonomous cursor chasing before the steal.
- Add a right-click action/status window with tab eating, cursor tricks, notes, speech, and live diagnostics.
- Ignore partial cursor target writes so the pointer cannot jump to a corner.
- Add squash and stretch during jumps and landings.

## 2026-11-27

- Emit dust and tab-crumb particles at exact bounce contact points.
- Detach particle emitters from Jeremy's moving transform.
- Expand particle emission from players, screen edges, and exact bounced edges.

## 2026-11-26 to 2026-11-27

- Add walking and jumping animations with separated sprite frames.
- Use `falling` on descent and bounces.
- Include the editable Aseprite source and import metadata.
- Document controls and optional animation names.
- Fix and stabilize the Windows single-file export workflow.

## 2026-11-26

- Initial Jeremy project: desktop pet physics, dialogue bubble, mouse passthrough, click/drag, bouncing, and celebration behavior.
