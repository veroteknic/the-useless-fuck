# jeremy

A tiny desktop pet for Windows, built with Godot 4.7.2.

Jeremy wanders and hops around on his own.

- Left-click: he says something.
- Left-drag and release: throw him.
- Right-click while a browser is focused: he eats that tab.

Animations are separated in `jeremy_sprite_frames.tres`. Optional animations named `jumping` and `eating` are picked up automatically when added. The editable art source is included as `jeremy.aseprite`.

Tiny dust puffs appear around Jeremy's left, right, and top when he walks, jumps, and bounces. Eating a tab throws crumbs from those same spots. Particles can be turned off with `particles_enabled` on the root script.

## Download

**Windows:** https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Every push to a branch builds a fresh self-contained `jeremy.exe` and replaces the asset on the `latest` release, so the link above always points at the newest build. Each Actions run also keeps a copy as a downloadable artifact.

## Development

- Open the project in Godot 4.7.2.
- Main scene: `main.tscn`.
- Windows export preset: `Windows Desktop` (single-file exe with the PCK embedded).
- The build workflow lives at `.github/workflows/build.yml`.
