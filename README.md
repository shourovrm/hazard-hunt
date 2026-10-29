<p align="center">
  <img src="assets/icon.png" alt="Hazard Hunt logo" width="140">
</p>

<h1 align="center">Hazard Hunt</h1>
<p align="center"><b>OSH training game</b> · পেশাগত নিরাপত্তা প্রশিক্ষণ গেম</p>

<p align="center">
  <a href="https://github.com/shourovrm/hazard-hunt/releases/download/v0.1.3/hazard-hunt-0.1.3.apk"><b>⬇ Download the latest Android APK</b></a>
  ·
  <a href="https://github.com/shourovrm/hazard-hunt/releases/latest">Release notes</a>
</p>

Hazard Hunt is an Android game for skills trainees in Bangladesh that teaches occupational safety and health (OSH). The player is a site supervisor. Each case shows an unsafe workplace, the player finds the hazards and answers questions, and then sees the same place made safe. The game runs offline, in Bangla or English, on low-cost phones.

<p align="center">
  <img src="docs/screenshots/splash.jpg" width="49%" alt="Opening screen with developer credit">
  <img src="docs/screenshots/main-menu.jpg" width="49%" alt="Main menu">
  <img src="docs/screenshots/sectors.jpg" width="49%" alt="Sector selection">
  <img src="docs/screenshots/construction-cases.jpg" width="49%" alt="Construction cases">
  <img src="docs/screenshots/hazard-hunt.jpg" width="49%" alt="Hazard hunt with the mentor">
  <img src="docs/screenshots/gate-check.jpg" width="49%" alt="Morning gate check">
  <img src="docs/screenshots/evidence-board.jpg" width="49%" alt="Near-miss investigation evidence board">
  <img src="docs/screenshots/line-art-case.jpg" width="49%" alt="Concrete mixer case in line-art style">
  <img src="docs/screenshots/diorama-case.jpg" width="49%" alt="Crane lifting case in diorama style">
</p>

## Cases

The construction sector has 8 cases. Garments (RMG) and light engineering are planned.

| # | Case | What the trainee practises |
|---|------|----------------------------|
| 1 | Bamboo scaffold: work at height | Finding hazards, hierarchy of controls, persuading a worker, PPE |
| 2 | Morning gate check | Checking each worker's helmet, boots and vest at the gate |
| 3 | Temporary electrical wiring | Lock-out tag-out, earth-leakage breakers, shock first aid |
| 4 | Foundation trench | Permit to work: mark each condition, then approve or refuse |
| 5 | Floor openings and edges | Covers, guardrails, safe carrying |
| 7 | Concrete mixer and rebar | Machine guards, loose clothing, cement dust, rebar caps |
| 8 | Crane lifting | Slings, tag lines, exclusion zones, the signaller's job |
| 12 | Near-miss investigation | Evidence board, open interview questions, 5 Whys, action plan |

Every question has a free **Hint**, and **Show answer** appears after a wrong try, so nobody gets stuck. Stars reward getting it right first time.

## Install

1. Download [`hazard-hunt-0.1.3.apk`](https://github.com/shourovrm/hazard-hunt/releases/download/v0.1.3/hazard-hunt-0.1.3.apk) on an Android phone (Android 7 or newer, OpenGL ES 3.0).
2. Open the file and allow installing from this source when Android asks.

## Build from source

Requirements: Godot 4.7.2 with the 4.7.2 Android export templates, the Android SDK, Java 21, and [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) for formatting and linting.

```sh
godot --path .                                               # run on the desktop
godot --headless --path . --import                           # import assets once
godot --headless --path . res://tests/test_runner.tscn       # run all tests
gdformat --check --line-length=120 core ui game tests        # format check
gdlint core ui game tests                                    # lint
godot --headless --path . --export-debug "Android" build/hazard-hunt.apk
```

## Project layout

- `core/`: case loading and validation, scoring, saved progress, language, sound.
- `ui/questions/`: one view per question type.
- `game/`: menu, sector page, case map, case player and animations.
- `content/`: sectors and cases as JSON, every text in Bangla and English. A new case is a new JSON file plus its images; see `docs/CONTRACT.md`.
- `assets/`: game images, fonts and sounds. `art_source/` holds the original generated images.
- `tests/`: automated tests for every module and every case.

## Content status

The case texts and legal references are drafts. An OSH expert must review them before the game is used in training. A review copy of all Bangla texts is in `docs/review/`.

## Credits

- Developer: Riad Mashrub Shourov (রিয়াদ মাশরুব সৌরভ).
- Illustrations generated with AI (OpenAI GPT Image) and edited for the game.
- Fonts: Noto Sans and Noto Sans Bengali, SIL Open Font License (`assets/fonts/OFL.txt`).
- Sound effects: Kenney (www.kenney.nl), CC0 (`assets/audio/CREDITS.txt`).

## License

MIT, see [`LICENSE`](LICENSE). The bundled fonts (SIL Open Font License) and sounds (CC0) keep their own licences.
