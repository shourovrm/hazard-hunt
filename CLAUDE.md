# OSH Safety Supervisor: project notes

- Godot 4.7.2, GDScript, Compatibility renderer, 1280×720 landscape. Interfaces: `docs/CONTRACT.md`.
- Slice verify: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . res://tests/test_runner.tscn -- --dir=<core|ui|game> 2>&1 | grep -E '^FAIL|tests,'`
- Full verify: the same runner without `--dir`, then `gdformat --check --line-length=120 core ui game tests` and `gdlint core ui game tests`.
- Exclusive files (main session only): `project.godot`, `content/**`, `assets/**`, `tests/**`, `core/localization.gd`, `docs/CONTRACT.md`.
- Art: generated with the image-gen skill (GPT Image); originals in `art_source/`, processed copies in `assets/`.
- CI/CD: not offered yet.
