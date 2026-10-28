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
func is_unlocked(case_ids: Array, case_id: String) -> bool  # first case always unlocked;
                                    # any other needs the previous id in case_ids completed
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
