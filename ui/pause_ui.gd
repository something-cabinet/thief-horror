extends Control
class_name PauseUI

@onready var pause_menu: Control = $PauseMenu
@onready var setting_ui: SettingUI = $SettingUI

var is_paused = false
var is_in_submenu = false

func _ready() -> void:
	GameManager.pause_ui = self
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		SoundManager.play_button_hover_sfx()
		if is_in_submenu:
			setting_ui.close_menu()
			return_to_pause_menu()
		elif is_paused:
			close_pause_menu()
		else:
			open_pause_menu()


func open_pause_menu():
	is_paused = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_pause_menu():
	is_paused = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func return_to_pause_menu():
	is_in_submenu = false
	pause_menu.visible = true

func _on_resume_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	close_pause_menu()

func _on_setting_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	setting_ui.open_menu()
	is_in_submenu = true
	pause_menu.visible = false

func _on_exit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	get_tree().quit()

func _on_title_screen_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	GameManager.go_back_to_title_screen()

func play_ui_hover_sound():
	SoundManager.play_button_hover_sfx()
