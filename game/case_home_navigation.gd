class_name CaseHomeNavigation
extends CanvasLayer
## Home button and leave confirm of the case player. Sits on a layer above the interface, so it
## stays tappable over the scene, the mentor strip and every panel.

signal home_pressed

const HOME_ICON_PATH := "res://assets/icons/home.svg"
const MAIN_MENU_SCENE := "res://game/main_menu.tscn"
const HOME_BUTTON_SIZE := Vector2(64, 64)
const SCREEN_MARGIN := 16.0
# The interface layer is 1; this one must be higher so the Home button is drawn over it.
const NAVIGATION_LAYER := 2

var _home_button: NavigationButton
var _leave_confirm: LeaveConfirmDialog


func _init() -> void:
	name = "Navigation"
	layer = NAVIGATION_LAYER
	_home_button = NavigationButton.new(HOME_ICON_PATH, HOME_BUTTON_SIZE)
	_home_button.name = "HomeButton"
	_home_button.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	_home_button.pressed.connect(_on_home_button_pressed)
	add_child(_home_button)
	_leave_confirm = LeaveConfirmDialog.new("leave_case_title", "leave_case_body", "leave")
	_leave_confirm.name = "LeaveConfirm"
	_leave_confirm.confirm_pressed.connect(confirm_leave)
	add_child(_leave_confirm)
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()


## Android back emits the same signal as the Home button, so the case player answers both in one place.
## project.godot turns quit_on_go_back off, which is why the game answers back itself.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		home_pressed.emit()


## On RESULT the progress is already saved, so leaving there does not ask again.
func request_leave(progress_is_saved: bool) -> void:
	if progress_is_saved:
		confirm_leave()
	else:
		_leave_confirm.open()


func cancel_leave() -> void:
	_leave_confirm.close()


func is_leave_confirm_visible() -> bool:
	return _leave_confirm.visible


func confirm_leave() -> void:
	Sfx.stop_ambience()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_home_button_pressed() -> void:
	Sfx.play("tap")
	home_pressed.emit()


func _on_language_changed(_language: String) -> void:
	_refresh_texts()


func _refresh_texts() -> void:
	_home_button.tooltip_text = Loc.ui("home")
