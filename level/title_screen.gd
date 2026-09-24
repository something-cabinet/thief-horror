extends Control

@onready var credit_panel: ColorRect = $CreditPanel
@onready var setting_ui: SettingUI = $SettingUI
@onready var start_button: Button = $TitleMenu/VBoxContainer/StartButton
@onready var background: ColorRect = $Background
@onready var level_preview: TextureRect = $LevelPreview

func _ready() -> void:
	credit_panel.visible = false
	setting_ui.visible = false
	if not GameManager.first_level_prepared.is_connected(show_level_preview):
		GameManager.first_level_prepared.connect(show_level_preview)
	GameManager.prepare_first_level()
	if GameManager.cached_first_level != null and not GameManager.is_preparing_first_level:
		show_level_preview()

func show_level_preview() -> void:
	# Level1 already renders in the main World3D behind this Control scene.
	level_preview.visible = false
	background.visible = false

func _on_start_button_pressed() -> void:
	play_button_click_sfx()
	start_button.disabled = true
	start_button.text = "Loading..."
	await GameManager.load_first_level()

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
