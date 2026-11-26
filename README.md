# jeremy

A tiny desktop pet for Windows, built with Godot 4.7.2.

Drag him around, click to talk, or right-click while a browser is focused if you feel like losing a tab.

## Download

**Windows:** https://github.com/veroteknic/the-useless-fuck/releases/latest/download/jeremy.exe

Every push to a branch builds a fresh self-contained `jeremy.exe` and replaces the asset on the `latest` release, so the link above always points at the newest build. Each Actions run also keeps a copy as a downloadable artifact.

## Development

- Open the project in Godot 4.7.2.
- Main scene: `main.tscn`.
- Windows export preset: `Windows Desktop` (single-file exe with the PCK embedded).
- The build workflow lives at `.github/workflows/build.yml`.
