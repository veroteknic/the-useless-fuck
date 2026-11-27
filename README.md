# jeremy

A tiny desktop pet for Windows, built with Godot 4.7.2.

Jeremy wanders and hops around on his own.

- Left-click: he says something.
- Left-drag and release: throw him.
- Right-click: opens Jeremy's action/status window. Use **eat tab** there to close the active browser tab.
- Middle-click: he snatches the pointer to his face for a moment, then loses interest. He may also chase a nearby pointer, but the grab only lands when the pointer is actually touching his hitbox. Pointer grabs use the same DPI-aware coordinates as the game, so they land correctly on scaled displays.

The right-click window has buttons for stealing the cursor, forcing a chase, writing a note, speaking, eating a tab, and closing the menu. It also shows live state, timers, position, and mouse coordinates for debugging.

Jeremy also gets bold on his own: he can cling to a wall, peek from the ceiling, tug a nearby cursor, and write himself real Windows Notepad windows. His idle chatter notices the time of day, weekdays, and weekends. Tabs he eats are counted per day.

Animations are separated in `jeremy_sprite_frames.tres`: `default`, `talkin`, `thumbs up!`, `flailing`, `falling`, `walking`, and `jumping`. An optional `eating` frame would be picked up automatically if added later. The editable art source is included as `jeremy.aseprite`.

Jeremy uses the bounds of whichever monitor he is currently on, so he does not fall into the empty space below a shorter secondary display.

Dust puffs appear exactly where Jeremy's collision circle touches the screen: left, right, top, or bottom. Walking and jumping kick up a little dust from the bottom contact point. Eating a tab throws crumbs from a random contact point. Particles can be turned off with `particles_enabled` on the root script.

## Download

**Windows:** https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Every push to a branch builds a fresh self-contained `jeremy.exe` and replaces the asset on the `latest` release, so the link above always points at the newest build. Each successful build also creates a distinct versioned release (`v0.1.<run number>`) with its own exe and generated changelog. See [releases](https://github.com/veroteknic/the-useless-fuck/releases) for version history or [CHANGELOG.md](CHANGELOG.md) for the readable summary.

## Development

- Open the project in Godot 4.7.2.
- Main scene: `main.tscn`.
- Windows export preset: `Windows Desktop` (single-file exe with the PCK embedded).
- The build workflow lives at `.github/workflows/build.yml`.
