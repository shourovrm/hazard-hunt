# OSH Safety Supervisor

Android training game for occupational safety and health (OSH) in Bangladesh. The player is a site
supervisor who finds hazards in an unsafe scene, answers questions, and then sees the same scene
made safe. The first sector is a construction site; case 1 is a bamboo scaffold at height.

## Install

- Godot 4.7.2 (`sudo pacman -S godot` on Arch) with the 4.7.2 Android export templates.
- Android SDK at `$ANDROID_HOME` and Java 17 or newer, for Android builds.
- gdtoolkit for formatting and linting: `uv tool install "gdtoolkit==4.*"`.

## Run

```
godot --path .            # opens the game window
godot --editor --path .   # opens the Godot editor
```

## Test

```
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn                 # all tests
godot --headless --path . res://tests/test_runner.tscn -- --dir=core   # one folder
gdformat --check --line-length=120 core ui game tests
gdlint core ui game tests
```

## Layout

- `core/`: case loading, case session logic, saved progress, language handling.
- `ui/`: question widgets, mentor panel, theme.
- `game/`: menu, sector map, case player.
- `content/`: case files (JSON) and UI strings in Bangla and English. A new case is a new JSON
  file plus its images; see `docs/CONTRACT.md` for the format.
- `assets/`: game-ready images and fonts. `art_source/` holds the original generated images.

## Content status

Case texts are drafts. An OSH expert must review every case, including the legal references,
before the game is used in training.

Illustrations were generated with AI (OpenAI GPT Image) and edited for the game.
