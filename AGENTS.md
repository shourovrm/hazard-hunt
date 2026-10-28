# Hazard Hunt

Android training game on occupational safety and health (OSH) for skills trainees in Bangladesh; Godot 4.7.2, GDScript, 2D, Bangla-first with English.

This file holds what is specific to this project: commands, memory layout, CI, delegation.
Interfaces between code areas are fixed in `docs/CONTRACT.md`; read the section you touch.

## Commands
- Setup: `sudo pacman -S godot` (4.7.2) plus 4.7.2 Android export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`; `uv tool install "gdtoolkit==4.*"`; Android SDK at `$ANDROID_HOME`, Java 21.
- Build (debug APK): `godot --headless --path . --export-debug "Android" build/hazard-hunt.apk`
- Build (release APK): set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` from `~/.config/hazard-hunt/release.env`, then `godot --headless --path . --export-release "Android" build/hazard-hunt.apk`
- Verify (slice, cheap): `godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . res://tests/test_runner.tscn -- --dir=<core|ui|game> 2>&1 | grep -E '^FAIL|tests,'`
- Verify (full): the runner without `--dir`, then `gdformat --check --line-length=120 core ui game tests`, `gdlint core ui game tests`, a debug APK build, and install on the phone.
- Lint / format: `gdformat --line-length=120 core ui game tests` and `gdlint core ui game tests` (max 1000 lines per file).
- Run locally: `godot --path .`; on the phone: `adb install -r build/hazard-hunt.apk && adb shell monkey -p bd.sicip.hazardhunt -c android.intent.category.LAUNCHER 1`
- Browser build (for scripted play tests): `godot --headless --path . --export-debug "Web" build/web/index.html`, serve `build/web` with `python3 -m http.server`.
- Release, in order: 1 bump `version/code` and `version/name` in `export_presets.cfg`; 2 full verify; 3 release APK build; 4 commit and tag `vX.Y.Z`; 5 `gh release create vX.Y.Z build/hazard-hunt.apk` (asset name must stay `hazard-hunt.apk`, the README links to `releases/latest/download/hazard-hunt.apk`).
- Exclusive resources (one session at a time): the USB phone (adb), `project.godot`, `content/**`, `assets/**`, `tests/**`, `core/localization.gd`, `docs/CONTRACT.md`.

## Content and art
- A case is one JSON file in `content/<sector>/cases/` plus its images; every text is `{"en", "bn"}`. New question types need a CONTRACT section, core scoring, a view, and tests.
- Case texts are drafts until an OSH expert reviews them; `docs/review/` holds the review document.
- Art is generated with GPT Image through the `image-gen` skill. Originals in `art_source/`, game copies in `assets/`. Show the user one mock before generating a batch.
- Workers are young, in proper workwear; women dress like Engineer Nasrin (salwar kameez, hijab), one case without hijab (case 7). Styles rotate per case: painted (cases 1–4, 12 office excepted), flat vector (5), navy/orange line art with paper motion (7, 12), clay diorama (8).

## CI/CD — undecided (offered 2026-10-29)
Pushing, opening a PR or tagging needs the user's approval in the current session, every time; committing does not.
Until CI exists, the full verify above runs locally before every push and release.

## Memory — MANDATORY
`DECISIONS.md` is an index. Knowledge lives in `docs/decisions/`. Git history holds events.

Files and hard caps:
- `DECISIONS.md` — at most 40 lines, no line over 200 characters. Sections: **Topics** (one line per topic file), **Next** (in-flight handoff, at most 5 bullets), **Gotchas (cross-cutting)** (only what every session needs).
- `docs/decisions/<topic>.md` — one per area, at most 80 lines. Sections: **Current state**, **Open items** (at most 5), **Gotchas**, **Tried / rejected** (one line: what + why dead; never re-attempt).
- `docs/decisions/ops.md` — config changes and manual steps: date, exact command, why.
- `docs/decisions/LOG.md` — append one line per decision under 160 characters: `YYYY-MM-DD | decision | why`. Read with `tail -20`; otherwise grep.

Rules:
- Current state is rewritten, not extended. Shipped work leaves Current state and Next in the same commit as the release.
- Before any work: read `DECISIONS.md`, then only the topic files the task touches. Before a new approach: `grep -ri <keyword> docs/decisions/`.
- Update in the same commit as the change it describes. New topic = new file + one index line.
- Pruning trigger: any file over its cap is the first task of the next session. Check with `wc -l DECISIONS.md docs/decisions/*.md; awk 'length > 200 {print FILENAME": "FNR}' DECISIONS.md`

## Local-only files
`CLAUDE.md`, `DECISIONS.md`, `docs/decisions/` and `.claude/` are gitignored (solo project). `AGENTS.md` and `docs/CONTRACT.md` are committed.

## Delegation
Every Agent call names its model. Tiers: haiku reads, searches and plays the browser build; the user has also approved haiku workers for small slices with tests written first. Sonnet implements one slice and runs its tests; opus plans, writes tests and reviews.
- Before spawning more than one worker, propose the split in at most five lines and wait for a yes (the `fan-out` skill), unless the user already set the number of agents.
- One worker per slice of disjoint files, each in its own worktree. Tests for a slice are written and committed by the main session first; workers never edit tests.
- `game/case_player.gd` sits near the 1000-line lint cap: workers move a self-contained block into a new file before adding code there.
- Workers run only their slice verify; the main session merges one slice at a time and runs the full verify once on the merged tree.

## Token economy
Terse replies, no filler; YAGNI; stdlib before dependencies; shortest working diff.
