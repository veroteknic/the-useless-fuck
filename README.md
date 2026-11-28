# jeremy

A tiny desktop pet for Windows, built with Godot 4.7.2.

Jeremy wanders and hops around on his own.

- Left-click: he says something.
- Left-drag and release: throw him.
- Right-click: opens Jeremy's action/status window. Use **eat tab** there to close the active browser tab, or **dramatic close** to close it and bring it straight back.
- Middle-click: he snatches the pointer to his face for a moment, then loses interest. He may also chase a nearby pointer, but the grab only lands when the pointer is actually touching his hitbox. Pointer grabs use the same DPI-aware coordinates as the game, so they land correctly on scaled displays.

The right-click window has buttons for stealing the cursor, forcing a chase, writing a note, speaking, eating a tab, dramatic close, allowing a non-browser window to be closed, and closing the menu. It also shows live state, timers, mood, the last autonomous choice, position, and mouse coordinates for debugging.

Jeremy also gets bold on his own: he can cling to a wall, peek from the ceiling, tug a nearby cursor, and write himself real Windows Notepad windows. His idle chatter notices the time of day, weekdays, and weekends. Tabs he eats are counted per day.

A single director-ticked `AutonomyBehavior` owns chatter timing, cursor timing, and weighted mischief choices. `main.gd` only supplies the concrete actions. Long idle stretches nudge the mood gates without changing the saved mood value.

Walking, jumping, and falling are owned by a single director-ticked `LocomotionBehavior`. `main.gd` stays the adapter for input, window placement, drag/eating/cursor hooks, and drawing. The action/status window shows which behaviours are currently running.

Animations are separated in `jeremy_sprite_frames.tres`: `default`, `talkin`, `thumbs up!`, `flailing`, `falling`, `walking`, and `jumping`. An optional `eating` frame would be picked up automatically if added later. The editable art source is included as `jeremy.aseprite`.

Jeremy's speech bubble, menu, and tab gag use an embedded Silkscreen pixel font, so they stay chunky and readable in the self-contained exe. The font is licensed under the SIL Open Font License 1.1; its notice is included at `assets/fonts/OFL.txt`. Notepad notes remain real Notepad windows and use Notepad's own font.

Jeremy uses the bounds of whichever monitor he is currently on, so he does not fall into the empty space below a shorter secondary display.

### Jeremy's mood and your content

- Jeremy keeps an always-visible chunky vertical **mood meter** pinned to the left edge of his current monitor. It starts full red when he is worked up and drains downward toward green as he calms (`sleepy` → `rambunctious`); a higher level means more rambunctious. It reacts to drags, cursor grabs, eaten tabs, dramatic closes, and you reading his notes. It is stored in `user://jeremy_mood.cfg`; a missing or corrupt file simply resets to neutral. The menu can hide the bar, and the whole overlay is click-through.
- **Mood escalation**: once he is `curious` he unlocks bolder cursor and tab behaviour; at `rambunctious` he may try a dramatic close. Idle time nudges him further up the bar. Personality weights and cooldowns keep the same trick from repeating back-to-back.
- **Dramatic close**: browser tabs are closed with `Ctrl+W` and restored with `Ctrl+Shift+T`. Non-browser windows are only eligible after you press **allow foreground close** with that window in front; Jeremy records a local allowlist in `user://jeremy_close_allowlist.cfg`, uses a graceful window close, and relaunches from the captured command line. Essential system, terminal, and Jeremy windows are denylisted. Nothing is killed.
- **Stubborn flail**: occasionally he resists being dragged for a moment, using his existing `flailing` animation. This never locks him in place.
- **Note reaction**: when you focus one of his Notepad windows briefly, he notices. He only closes the note if its text is unchanged, so your edits are never lost.
- Right-click menu has toggles and sliders for pause, mischief, mischief intensity, autonomous activity frequency, dialogue frequency, individual gags, mood meter, dramatic close, and user content.

You can add your own content without changing the game:

- `user://jeremy_custom_notes.txt` — one note line per line; `#` starts a comment.
- `user://jeremy_custom_dialogue.txt` — one speech line per line; `#` starts a comment.
- `user://jeremy_popins/` — PNG/JPG/JPEG/WEBP images shown briefly near Jeremy. Nothing is bundled or copied from another character or game.

On Windows these live under `%APPDATA%\Godot\app_userdata\the useless fuck\`.

Dust puffs appear exactly where Jeremy's collision circle touches the screen: left, right, top, or bottom. Walking and jumping kick up a little dust from the bottom contact point. Eating a tab throws crumbs from a random contact point. Particles can be turned off with `particles_enabled` on the root script.

## Download

**Windows:** https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Every push to a branch builds a fresh self-contained `jeremy.exe` and replaces the asset on the `latest` release, so the link above always points at the newest build. Each successful build also creates a distinct versioned release (`v0.1.<run number>`) with its own exe and generated changelog. See [releases](https://github.com/veroteknic/the-useless-fuck/releases) for version history or [CHANGELOG.md](CHANGELOG.md) for the readable summary.

## Development

- Open the project in Godot 4.7.2.
- Main scene: `main.tscn`.
- Windows export preset: `Windows Desktop` (single-file exe with the PCK embedded).
- The build workflow lives at `.github/workflows/build.yml`.
