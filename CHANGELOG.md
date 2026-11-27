# Changelog

Every successful push builds a versioned GitHub release named `v0.1.<workflow run number>`. The `latest` release is kept up to date and always serves the same single-file build at:

https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Use the [releases page](https://github.com/veroteknic/the-useless-fuck/releases) for the complete version-by-version history. Each versioned release also includes a generated `changelog.txt` asset.

## 2026-11-27

- Add a behaviour director skeleton as the single request/status authority for future autonomous behaviours.
- Add one canonical state readout used by the action/status menu.
- Add a drag-release watchdog so a lost mouse-up cannot leave Jeremy stuck.
- Stop cursor cooldowns being consumed by rejected steal/chase attempts.
- Validate dialogue and menu calls before dispatch, and keep speech latches from getting trapped during tab eating.
- Aim cursor grabs directly at Jeremy's face instead of his body centre.
- Only trigger cursor grabs when the pointer actually intersects Jeremy's hitbox.
- Make the pointer helper DPI-aware so grabs land on the face instead of down/right on scaled displays.
- Correct the animation documentation: `jumping` exists; `eating` remains optional.

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
