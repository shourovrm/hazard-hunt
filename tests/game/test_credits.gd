extends RefCounted

const MainMenuScene := preload("res://game/main_menu.tscn")
const SplashScene := preload("res://game/splash.tscn")

var t


func test_main_menu_shows_developer_and_version() -> void:
	var menu: Node = MainMenuScene.instantiate()
	t.root.add_child(menu)
	Loc.set_language("en")
	var text: String = t.collect_text(menu)
	t.assert_true("Developed by Riad Mashrub Shourov" in text, "developer credit missing")
	t.assert_true(str(ProjectSettings.get_setting("application/config/version")) in text, "version missing")
	Loc.set_language("bn")
	t.assert_true("রিয়াদ মাশরুব সৌরভ" in t.collect_text(menu), "Bangla developer name missing")
	Loc.set_language("en")


func test_splash_shows_title_and_developer() -> void:
	var splash: Node = SplashScene.instantiate()
	splash.auto_advance = false
	t.root.add_child(splash)
	Loc.set_language("en")
	var text: String = t.collect_text(splash)
	t.assert_true("Hazard Hunt" in text, "title missing on splash")
	t.assert_true(Loc.ui("developed_by") in text, "developed-by label missing on splash")
	t.assert_true(Loc.ui("developer_name") in text, "developer name missing on splash")


func test_app_starts_on_splash() -> void:
	t.assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://game/splash.tscn")
