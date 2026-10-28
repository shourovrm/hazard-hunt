# Code contract

This file fixes the interfaces between the three code areas. Each area codes against these
signatures only. Change this file in the main session, never inside a slice.

Engine: Godot 4.7, GDScript, Compatibility renderer, 1280×720 virtual landscape screen
(`canvas_items` stretch, `expand` aspect). All text on screen comes from `Loc.text()` or
`Loc.ui()`; never hard-code display strings. Case files are the format reference:
`content/construction/cases/c01_bamboo_scaffold.json`.

## Shared (main session owns)

- `core/localization.gd`, autoload `Loc`:
  `language: String` ("bn" default, or "en"), `signal language_changed(language)`,
  `set_language(code)`, `text(localized: Dictionary) -> String`,
  `ui(key: String, values := {}) -> String` (keys in `content/ui_strings.json`),
  `number(value: int) -> String`.
- `content/**`, `assets/**`, `project.godot`, `tests/test_runner.*`, `tests/test_context.gd`.
- A slice that needs a new UI string reports the key and both texts; it does not edit
  `content/ui_strings.json`.

## Area A: core logic (`core/case_loader.gd`, `core/case_session.gd`, `core/progress_store.gd`)

No UI code, no scene nodes except `ProgressStore` (a Node so it can be an autoload).

### `class_name CaseLoader extends RefCounted` (static functions only)

- `static func load_case(path: String) -> Dictionary`: reads and parses the JSON, runs
  `validate`, and on any read, parse or validation error calls `push_error` with the path
  and every problem, then returns `{}`.
- `static func validate(case_data: Dictionary) -> Array[String]`: returns one readable
  message per problem; empty means valid. Checks:
  - `id`, `title`, `scene`, `intro`, `hazards`, `questions`, `outcome` exist.
  - Every localized text (`title`, `intro`, hazard `label`/`explain`, question `prompt`/`hint`/
    `explanation`, option/item `text`, dialogue `npc_line`, choice `text`/`reply`/`feedback`)
    has both `en` and `bn`.
  - Each hazard `rect` is 4 numbers with positive width and height.
  - Question `type` is one of `single_choice`, `multi_select`, `ordering`, `dialogue`,
    `drag_ppe`; question ids are unique.
  - `single_choice`: `correct` is an option id. `multi_select` and `drag_ppe`: `correct` is a
    non-empty array of known option/item ids. `ordering`: `correct_order` is a permutation of
    the item ids. `dialogue`: each choice `quality` is `best`, `ok` or `fail`, and at least one
    choice is `best`.
- `static func load_sector(path: String) -> Dictionary`: parses a sector file such as
  `content/construction/sector.json`; returns `{}` with `push_error` on failure.

### `class_name CaseSession extends RefCounted`

One play-through of one case. Pure logic; the UI reads it and calls it.

```
enum Phase { INTRO, HAZARD_HUNT, QUESTIONS, SAFE_REVEAL, RESULT }
const TAP_PADDING := 16.0          # px added on every side of a hazard rect
const MISSES_PER_MISTAKE := 3      # every 3rd wrong tap counts as one mistake and shows a hint

signal phase_changed(phase: Phase)

func _init(case_data: Dictionary)  # data already validated by CaseLoader
var case_data: Dictionary          # read-only for callers
var phase: Phase                   # starts at INTRO

func begin_hazard_hunt() -> void   # INTRO -> HAZARD_HUNT
func tap(point: Vector2) -> Dictionary
func found_hazard_ids() -> Array[String]   # in the order found
func hint_hazard_id() -> String            # first hazard (file order) not yet found, "" if none
func all_hazards_found() -> bool
func finish_hazard_hunt() -> bool          # HAZARD_HUNT -> QUESTIONS only if all found; else false

func question_index() -> int               # 0-based
func question_count() -> int
func current_question() -> Dictionary     # {} outside QUESTIONS
func submit_answer(answer: Variant) -> Dictionary
func next_question() -> bool    # only after the current question was answered correctly.
                                # true: moved to next question. false: no more questions,
                                # phase is now SAFE_REVEAL. Calling it before a correct answer
                                # does nothing, calls push_error and returns false.
func finish_reveal() -> void    # SAFE_REVEAL -> RESULT
func mistakes() -> int
func stars() -> int             # 3 if mistakes == 0, 2 if mistakes <= 2, else 1
func result() -> Dictionary     # {"case_id", "stars", "mistakes", "hazards_found": int}
```

Every phase change emits `phase_changed`. Calling a method in the wrong phase calls
`push_error` and returns the "empty" value (`{}`, `false`, nothing).

`tap(point)` (point in 1280×720 scene coordinates) returns:
`{"hit": bool, "hazard_id": String ("" on a miss), "already_found": bool,
"show_hint": bool, "all_found": bool}`. A miss increments a miss counter; when the counter
reaches a multiple of `MISSES_PER_MISTAKE`, `show_hint` is true and one mistake is added.

`submit_answer(answer)` answer shapes by question type:

| type | answer | correct when |
|---|---|---|
| single_choice | `String` option id | equals `correct` |
| multi_select | `Array` of option ids | same set as `correct` (order ignored) |
| ordering | `Array` of item ids | exactly equals `correct_order` |
| dialogue | `String` choice id | chosen choice `quality` is `best` or `ok` |
| drag_ppe | `Array` of item ids | same set as `correct` |

It returns `{"correct": bool, "quality": String, "hint": Dictionary, "explanation": Dictionary,
"reply": Dictionary, "feedback": Dictionary}`. `quality` is `"best"`/`"ok"`/`"fail"` for
dialogue and `"best"` (correct) or `"fail"` (wrong) for other types. `hint` is the question's
hint when wrong, else `{}`. `explanation` is the question's explanation when correct, else `{}`.
`reply` and `feedback` come from the chosen dialogue choice, `{}` for other types.
Mistakes: +1 for each wrong submission, +1 for a dialogue `ok` choice. A correct submission
after a correct submission on the same question is ignored (returns the same result, no
mistake change).

### `class_name ProgressStore extends Node` (autoload `Progress`)

```
var save_path := "user://progress.json"
func load_progress() -> void        # called in _ready; a missing file is fine; a corrupt file
                                    # calls push_error and starts empty
func save_progress() -> void        # writes JSON; push_error on failure
func record_result(case_id: String, stars: int) -> void   # keeps the best stars; saves
func get_stars(case_id: String) -> int                    # 0 if never completed
func is_completed(case_id: String) -> bool
func is_unlocked(case_ids: Array, case_id: String) -> bool  # every listed case is unlocked
                                    # (user decision 2026-10-29); unknown id: push_error, false
func get_language() -> String       # saved language, "bn" by default
func set_language(code: String) -> void   # saves
func reset() -> void                # clears everything in memory and on disk
```

## Area B: question widgets (`ui/questions/**`)

- `class_name QuestionView extends Control` in `ui/questions/question_view.gd`; one subclass per
  type: `single_choice_view.gd`, `multi_select_view.gd`, `ordering_view.gd`, `dialogue_view.gd`,
  `drag_ppe_view.gd` (scenes optional; building UI in code is fine).
- `class_name QuestionFactory extends RefCounted`, `static func create(question: Dictionary) ->
  QuestionView`: the right subclass, already `setup()`; unknown type: `push_error`, `null`.

QuestionView API:

```
signal answer_submitted(answer: Variant)   # shape from the table in Area A
var question: Dictionary
func setup(question: Dictionary) -> void
func get_answer() -> Variant               # current selection in the answer shape
func set_answer(answer: Variant) -> void   # set the selection programmatically (tests, replays)
func submit() -> void                      # emits answer_submitted(get_answer())
func show_result(result: Dictionary) -> void  # result from CaseSession.submit_answer
func is_locked() -> bool                   # true after a correct result; input disabled
```

Behaviour:
- Each view shows the prompt and its own Submit button (`Loc.ui("submit")`), disabled until a
  valid selection exists (dialogue submits on tapping a choice; no Submit button needed).
- On a wrong result: show `Loc.ui("try_again")` and the hint, keep the input enabled, and
  for dialogue show the NPC `reply` and `feedback`.
- On a correct result: show `Loc.ui("correct")` and the explanation (and dialogue
  `reply`/`feedback`), lock the input.
- Rebuild all visible text when `Loc.language_changed` fires.
- `ordering`: starts in a shuffled order that is never equal to `correct_order`; items move with
  up/down buttons (touch friendly), labelled top `most_effective`, bottom `least_effective`;
  shows each item's `tag` only after a correct result.
- `drag_ppe`: shows `target_image` (worker) and the item icons. An item is dragged onto the
  worker to equip it, or tapped to toggle (fallback for small screens). Tray buttons never move:
  an equipped item stays in its tray slot, visibly marked as equipped, and tapping it again
  removes it. After a correct result the worker image switches to `target_image_safe` when the
  question has one.
- After a correct result the Submit button is hidden, and after any result the scroll area
  scrolls so the feedback text is visible.
- `dialogue`: shows `npc_portrait`, `npc_name` and `npc_line` as a speech bubble, and each
  choice as a full-width button.
- Touch targets at least 64 px high; text 24 px or larger; layout fits a 1280×720 panel area of
  at most 760×560 px (the case player puts the view beside the scene).

## Area C: game screens (`game/**`, `ui/theme/**`, `ui/mentor_panel.*`)

- `game/main_menu.tscn`: title (`app_title`, `app_subtitle`), Start button (`Loc.ui("start")`),
  language switch button (`language_switch`; calls `Loc.set_language` and
  `Progress.set_language`). Applies `Progress.get_language()` on start. Background:
  `assets/construction/c01/bg_safe.png` dimmed.
- `game/sector_map.tscn`: sector title, one card per case (title, stars from `Progress`,
  Play button, locked state), and one disabled card per `coming_soon` entry.
- `game/case_player.tscn` with script `game/case_player.gd`, which drives a `CaseSession`:
  - INTRO: unsafe scene; camera pans across the scene once; mentor panel says `intro`; tap to
    continue → HAZARD_HUNT.
  - HAZARD_HUNT: counter `hazards_found`; a tap on the scene calls `CaseSession.tap`; a hit
    draws a ring on the hazard and the mentor shows `label` and `explain`; a miss shows
    `not_a_hazard`; `show_hint` pulses the `hint_hazard_id` rect and shows `hazard_hint`. After
    all found, `all_hazards_found`, then continue → QUESTIONS.
  - QUESTIONS: scene stays visible (left), question panel (right) hosts
    `QuestionFactory.create(current_question())`, `question_counter` above it. On
    `answer_submitted`, call `submit_answer` and pass the result to `show_result`; after a
    correct answer a Next button calls `next_question()`.
  - SAFE_REVEAL: crossfade background and actors to `safe` textures, actors move to
    `safe_position`, sparkle on each fixed hazard, mentor says `outcome.mentor_line`, list
    `outcome.fixes`; continue → RESULT.
  - RESULT: `case_complete`, stars, mistakes, `references`, `draft_notice` if the case has a
    `review_status` starting with "draft"; `Progress.record_result`; buttons `play_again`,
    `back_to_map`.
  - Actors: `Sprite2D` with bottom-centre at `position`, `scale` from the file; idle
    animations by tween: `breathe` (slow 2 % vertical scale pulse), `work` (small rotation
    bob of the whole sprite). Ambient `dust`: a light `CPUParticles2D` near the ground.
  - Test hooks: `var animations_enabled := true` (false makes every transition immediate),
    `func start_case(path: String) -> void`, `func get_session() -> CaseSession`,
    `func skip_intro() -> void`, `func handle_scene_tap(scene_point: Vector2) -> void`,
    `func get_active_question_view() -> QuestionView`, `func advance() -> void` (same as the
    visible Continue/Next button of the current step), `func background_state() -> String`
    ("unsafe" or "safe"), `func is_result_visible() -> bool`.
  - Wide screens: screens wider than 16:9 show a `Backdrop` node (TextureRect or Sprite2D named
    "Backdrop") behind the scene: the current background, blurred (downscale to about 1/20 and
    scale back up with bilinear filtering, done once per texture at load) and darkened, sized to
    cover the whole viewport. It follows the unsafe/safe crossfade. No black bars remain.
- `ui/mentor_panel.tscn` + `.gd`: portrait `assets/characters/mentor_portrait.png`, name
  `mentor_name`, `func say(localized: Dictionary) -> void`, text appears with a short
  type-on effect (skippable by tap).
- Scene changes go through `get_tree().change_scene_to_file`; the case path to play is passed
  through a small static var `game/game_state.gd` (`class_name GameState`,
  `static var selected_case_path: String`).
- Performance: 2D only, no shaders beyond built-ins, `CPUParticles2D` only, at most ~40
  particles, no per-frame allocations in `_process`.

## Sound (`core/sound_player.gd`, autoload `Sfx`)

Files are in `assets/audio/` (CC0, see `assets/audio/CREDITS.txt`). Sound names map to
`res://assets/audio/<name>.ogg`.

```
const SOUND_NAMES: Array[String] = ["tap", "select", "hazard_found", "miss", "correct", "wrong", "next", "case_complete"]
func has_sound(sound_name: String) -> bool
func play(sound_name: String) -> void      # unknown name: push_error; muted: plays nothing
func play_ambience(path: String) -> void   # loops, about -14 dB, short fade in; replaces any current ambience
func stop_ambience() -> void               # short fade out
func current_ambience() -> String          # "" when none
func set_muted(muted: bool) -> void        # also mutes ambience; saved with Progress.set_sound_enabled
func is_muted() -> bool                    # on start reads Progress.get_sound_enabled()
```

Several sound effects can overlap (a small pool of AudioStreamPlayer nodes). Streams are
preloaded once. `ProgressStore` gains `get_sound_enabled() -> bool` (default true) and
`set_sound_enabled(enabled: bool)` (saves).

Where sounds play:
- Every Button press in main menu, sector map and case player: `tap` (Next/Continue use `next`).
- QuestionView: choosing or reordering an option or equipping PPE: `select`; `show_result`:
  `correct` or `wrong`.
- Case player: hazard hit (new): `hazard_found`; miss: `miss`; result screen: `case_complete`.
  `start_case` calls `Sfx.play_ambience(scene.ambience)` when the case has one; leaving the case
  player (scene exit) calls `Sfx.stop_ambience()`.
- Main menu: a sound toggle button showing `Loc.ui("sound_on")` or `Loc.ui("sound_off")`.

## Gate check question type (`gate_check`) and cases without hazards

Reference data: `content/construction/cases/c02_gate_check.json`.

### Core (CaseLoader, CaseSession)

- `hazards` may be an empty array. Then `CaseSession.begin_hazard_hunt()` goes straight from
  INTRO to QUESTIONS (emitting `phase_changed(QUESTIONS)` once), and `hazard_hint` is optional.
- `validate` accepts type `gate_check` and checks: `ppe_items` is a non-empty array of
  `{id, icon, text}`; `workers` is a non-empty array of `{id, name, image, image_safe, missing,
  feedback}` with unique ids, `name` and `feedback` localized in en and bn, and every `missing` id
  is a `ppe_items` id (an empty `missing` means the worker may enter).
- Answer shape: `Dictionary` of worker id → `Array` of ppe ids the player marked missing on their
  FIRST decision for that worker. The widget lets the player correct mistakes before moving on,
  so the question always ends complete.
- `submit_answer` for `gate_check`: if any worker id is absent from the answer → `correct: false`,
  `quality: "fail"`, hint, +1 mistake. Otherwise `correct: true`, mistakes += number of workers
  whose first decision did not match `missing` (set comparison), `quality` is `"best"` when that
  number is 0, else `"ok"`; `explanation` is returned as usual.

### Widget (`ui/questions/gate_check_view.gd`, registered in QuestionFactory)

- Shows one worker at a time: large `image`, `name`, `Loc.ui("worker_counter", {number, total})`,
  `Loc.ui("mark_missing")`, and one toggle per `ppe_items` entry (icon + text, 64 px+ high).
- One action button: `Loc.ui("let_in")` when nothing is marked, `Loc.ui("send_back")` otherwise.
- Pressing it compares the marked set with the worker's `missing`. The first decision for each
  worker is recorded for the answer. Right: show `Loc.ui("correct")` and the worker's `feedback`,
  switch the image to `image_safe` if the worker was sent back, and show a
  `Loc.ui("next_worker")` button (on the last worker, the view calls `submit()` instead).
  Wrong: show `Loc.ui("try_again")` and the question `hint`; the toggles stay editable.
- Test hooks: `current_worker_index() -> int`, `set_marked(ppe_id: String, marked: bool)`,
  `decide() -> bool` (presses the action button, returns whether the decision was right),
  `next_worker()`. `set_answer(answer: Dictionary)` records those first decisions for every
  worker and moves to the end so `submit()` emits them; `get_answer()` returns the recorded
  first decisions.
- `show_result`: as other views (lock on correct, show explanation).

### Case player

- When the case has no hazards, Continue after the intro goes straight to QUESTIONS (no hunt UI,
  no hazard counter). `skip_intro()` does the same.

## Hints (free help)

Hints never change scoring: they add no mistake and do not lower stars.

- QuestionView: while not locked and the question has a `hint`, show a Hint button
  (`Loc.ui("hint_button")`). Pressing it, or calling `show_hint()`, shows the question's `hint`
  text in the feedback area (same place the hint appears after a wrong answer) and plays
  `select`. The Hint button is hidden once the view is locked. Applies to every type, including
  `gate_check` (it shows the question hint for the current worker).
- Case player, HAZARD_HUNT: a Hint button (`Loc.ui("hint_button")`) next to the hazard counter.
  Pressing it, or calling `request_hint()`, pulses the ring at `session.hint_hazard_id()` and the
  mentor shows `hazard_hint`. It does not change `session.mistakes()`. Hidden outside the hunt.

## Permit check question type (`permit_check`)

Reference data: the `dig_permit` question in `content/construction/cases/c04_trench.json`.
The player inspects the scene, marks each permit condition OK or Not OK, then approves or refuses.

### Core

- `validate`: `permit_title` localized (en, bn); `checks` is a non-empty array of
  `{id, text, status}` with unique ids, `text` localized, `status` either `"ok"` or `"not_ok"`;
  `correct_decision` is `"approve"` or `"refuse"`, and it must be `"refuse"` when any check is
  `"not_ok"` and `"approve"` when all are `"ok"` (report a mismatch).
- Answer shape: `{"marks": {check_id: "ok" | "not_ok", ...}, "decision": "approve" | "refuse"}`.
- `submit_answer`: correct only when every check id is marked with its `status` and `decision`
  equals `correct_decision`. Otherwise the normal wrong result (hint, +1 mistake, retry).

### Widget (`ui/questions/permit_check_view.gd`, registered in QuestionFactory)

- Looks like a paper permit form inside the panel: `permit_title` as a heading, then one row per
  check: the check text and two toggle buttons `Loc.ui("check_ok")` and `Loc.ui("check_not_ok")`
  (exactly one can be selected per row; 64 px+ touch height; text wraps).
- Below: two buttons, `Loc.ui("approve_permit")` and `Loc.ui("refuse_permit")` (refuse uses the
  PrimaryButton look). Both are disabled until every row is marked. Pressing one sets the
  decision and calls `submit()`. There is no separate Submit button (`_uses_submit_button()`
  false). The Hint button from QuestionView stays.
- Wrong result: try_again + hint, marks stay editable. Correct result: lock, explanation, and
  each row shows its correct status in green (OK) or red (Not OK).
- Test hooks: `set_mark(check_id: String, status: String)`, `choose_decision(decision: String)`
  (sets the decision and submits, only if all rows are marked), plus the usual
  `get_answer()` / `set_answer(answer)` with the answer shape above.

## Show answer (so nobody gets stuck)

- Core: `CaseSession.correct_answer(question: Dictionary) -> Variant` (static). Returns the answer
  in the shape `submit_answer` expects that is fully correct: `correct` (single, multi, drag_ppe),
  `correct_order` (ordering), the id of the first `best` choice (dialogue), a worker id → `missing`
  dictionary (gate_check), `{marks: {id: status}, decision: correct_decision}` (permit_check).
- QuestionView: a `Loc.ui("show_answer")` button appears only after the view has received a
  wrong result (or, for gate_check, after a wrong decision on the current worker), and only while
  the view is not locked. Pressing it, or calling `show_solution()`, selects the correct answer in
  the UI (for gate_check: marks the current worker's missing items only) and shows
  `Loc.ui("solution_shown")`. The player still presses Submit / the decision / the dialogue choice
  to continue. Scoring is unchanged: the earlier wrong try already counted; showing the answer
  adds nothing.

## Home and exit on every screen

Icons: `res://assets/icons/home.svg` and `res://assets/icons/exit.svg` (white strokes; put them on
a navy round or rounded-square button, at least 64×64 px, top-left corner, always on top).

- Main menu: an Exit button (icon + `Loc.ui("exit_game")`). Pressing it, or the Android back
  button, shows a confirm dialog (`quit_title`, buttons `stay` / `exit_game`); confirming calls
  `get_tree().quit()`.
- Sector map: a Home button (icon + `Loc.ui("home")`) top-left that returns to the main menu. The
  Android back button does the same. (It may replace the existing Back button.)
- Case player: a Home icon button named `HomeButton`, visible in every phase (intro, hunt,
  questions, reveal, result), drawn above the scene and panels. Pressing it, the Android back
  button, or calling `request_home()` shows a confirm dialog named `LeaveConfirm` with
  `leave_case_title`, `leave_case_body` and buttons `stay` / `leave`. `cancel_leave()` hides it;
  `confirm_leave()` stops ambience and changes scene to the main menu. On the RESULT screen the
  progress is already saved, so Home goes straight to the main menu without the dialog.
- Android back: handle `NOTIFICATION_WM_GO_BACK_REQUEST` in each screen
  (`application/config/quit_on_go_back` is disabled in project.godot so the game decides).
- Test hooks (case player): `request_home()`, `cancel_leave()`, `is_leave_confirm_visible() -> bool`.
  Main menu: `request_quit()`, `is_quit_confirm_visible() -> bool`.
