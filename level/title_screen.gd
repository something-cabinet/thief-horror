extends Control

@onready var credit_panel: ColorRect = $CreditPanel
@onready var setting_ui: SettingUI = $SettingUI

func _ready() -> void:
	credit_panel.visible = false
	setting_ui.visible = false

func _on_start_button_pressed() -> void:
	play_button_click_sfx()
	GameManager.load_first_level()

func _on_setting_button_pressed() -> void:
	play_button_click_sfx()
	setting_ui.visible = !setting_ui.visible
	credit_panel.visible = false

func _on_credit_button_pressed() -> void:
	play_button_click_sfx()
	credit_panel.visible = !credit_panel.visible
	setting_ui.visible = false

func _on_quit_button_pressed() -> void:
	play_button_click_sfx()
	get_tree().quit()

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()

func play_button_click_sfx():
	SoundManager.play_button_click_sfx()
