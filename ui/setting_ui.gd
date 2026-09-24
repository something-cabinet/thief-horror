extends Control
class_name SettingUI

@onready var tab_container: TabContainer = %TabContainer

@onready var mouse_sen_slider: HSlider = %MouseSenSlider
@onready var mouse_sen_value: Label = %MouseSensValue
@onready var fov_slider: HSlider = %FOVSlider
@onready var fov_value: Label = %FOVValue
@onready var camera_tilt_toggle: CheckButton = %CameraTiltToggle
@onready var fps_limit_option_button: OptionButton = %FPSLimitOptionButton
@onready var vsync_option_button: OptionButton = %VsyncOptionButton
@onready var window_mode_option_button: OptionButton = %WindowModeOptionButton
@onready var resolution_option_button: OptionButton = %ResolutionOptionButton
@onready var scaling_3d_slider: HSlider = %Scaling3DSlider
@onready var scaling_3d_value: Label = %Scaling3DValue

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var bgm_slider: HSlider = %BGMSlider
@onready var bgm_value: Label = %BGMValue
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var ui_slider: HSlider = %UISlider
@onready var ui_value: Label = %UIValue

@export var keybind_button_prefab: PackedScene
@onready var keybind_container: Control = %KeybindingSection

var pause_ui: PauseUI
var keybindable_action_list = {
	"up": "Move forward",
	"down": "Move backward",
	"left": "Move left",
	"right": "Move right",
	"jump": "Jump",
	"dash": "Dash",
	"crouch": "Crouch/Slam",
	"primary_attack": "Primary attack",
	"secondary_attack": "Secondary attack",
	"weapon_slot_1": "Weapon slot 1",
	"weapon_slot_2": "Weapon slot 2",
	"pause_menu": "Pause Menu",
}
var is_remapping = false
var action_to_remap = null
var remapping_button: KeybindButton = null

func _ready() -> void:
	visible = false
	if get_parent() is PauseUI:
		pause_ui = get_parent()

	mouse_sen_slider.value = GameManager.mouse_sensitivity
	mouse_sen_value.text = "{0}".format([GameManager.mouse_sensitivity])

	fov_slider.value = GameManager.camera_fov
	fov_value.text = "{0}".format([GameManager.camera_fov])

	camera_tilt_toggle.set_pressed_no_signal(GameManager.camera_tilt)

	Engine.max_fps = EnumAutoload.FPS_LIMIT_ARRAY[GameManager.fps_limit_index]
	fps_limit_option_button.selected = GameManager.fps_limit_index

	DisplayServer.window_set_vsync_mode(GameManager.vsync_option_index)
	vsync_option_button.selected = GameManager.vsync_option_index

	populate_resolution_options()
	resolution_option_button.selected = GameManager.resolution_index

	window_mode_option_button.selected = GameManager.window_mode_index

	get_viewport().set_scaling_3d_scale(GameManager.scaling_3d / 100.0)
	scaling_3d_slider.value = GameManager.scaling_3d
	scaling_3d_value.text = "{0}%".format([GameManager.scaling_3d])

	SoundManager.set_master_volume(GameManager.master_audio / 100.0)
	SoundManager.set_music_volume(GameManager.bgm_audio / 100.0)
	SoundManager.set_sound_volume(GameManager.sfx_audio / 100.0)
	SoundManager.set_ui_sound_volume(GameManager.ui_audio / 100.0)
	master_slider.value = GameManager.master_audio
	master_value.text = "{0}".format([GameManager.master_audio])
	bgm_slider.value = GameManager.bgm_audio
	bgm_value.text = "{0}".format([GameManager.bgm_audio])
	sfx_slider.value = GameManager.sfx_audio
	sfx_value.text = "{0}".format([GameManager.sfx_audio])
	ui_slider.value = GameManager.ui_audio
	ui_value.text = "{0}".format([GameManager.ui_audio])

	create_keybind_buttons()

func _input(event):
	if is_remapping:
		if (event is InputEventKey || (event is InputEventMouseButton && event.pressed)):
			if event is InputEventMouseButton && event.double_click:
				event.double_click = false
			InputMap.action_erase_events(action_to_remap)
			InputMap.action_add_event(action_to_remap, event)
			remapping_button.input_button.text = event.as_text().trim_suffix(" (Physical)")
			is_remapping = false
			action_to_remap = null
			remapping_button = null
			accept_event()

func open_menu():
	visible = true

func close_menu():
	visible = false

func _on_back_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	close_menu()
	if pause_ui:
		pause_ui.return_to_pause_menu()

func _on_mouse_sen_slider_value_changed(value: float) -> void:
	GameManager.mouse_sensitivity = value
	mouse_sen_value.text = "{0}".format([value])

func _on_fov_slider_value_changed(value: float) -> void:
	GameManager.camera_fov = value
	fov_value.text = "{0}".format([value])

func _on_camera_tilt_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.camera_tilt = toggled_on

func _on_fps_limit_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	Engine.max_fps = EnumAutoload.FPS_LIMIT_ARRAY[index]
	GameManager.fps_limit_index = index

func _on_vsync_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	DisplayServer.window_set_vsync_mode(index)
	GameManager.vsync_option_index = index

func _on_resolution_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	DisplayServer.window_set_size(EnumAutoload.RESOLUTION_ARRAY[index])
	GameManager.resolution_index = index
	centre_window()

func _on_master_slider_value_changed(value: float) -> void:
	SoundManager.set_master_volume(value / 100.0)
	master_value.text = "{0}".format([value])
	GameManager.master_audio = value

func _on_ui_slider_value_changed(value: float) -> void:
	SoundManager.set_ui_sound_volume(value / 100.0)
	ui_value.text = "{0}".format([value])
	GameManager.ui_audio = value

func _on_sfx_slider_value_changed(value: float) -> void:
	SoundManager.set_sound_volume(value / 100.0)
	sfx_value.text = "{0}".format([value])
	GameManager.sfx_audio = value

func _on_bgm_slider_value_changed(value: float) -> void:
	SoundManager.set_music_volume(value / 100.0)
	bgm_value.text = "{0}".format([value])
	GameManager.bgm_audio = value

func _on_scaling_3d_slider_value_changed(value: float) -> void:
	GameManager.scaling_3d = value
	get_viewport().set_scaling_3d_scale(value / 100.0)
	scaling_3d_value.text = "{0}%".format([value])

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()

func set_window_mode(index: int) -> void:
	match index:
		0: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			resolution_option_button.disabled = true
			var resolution_text = str(get_window().get_size().x) + "x" + str(get_window().get_size().y)
			resolution_option_button.set_text(resolution_text)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(EnumAutoload.RESOLUTION_ARRAY[GameManager.resolution_index])
			centre_window()
			resolution_option_button.disabled = false
			resolution_option_button.selected = GameManager.resolution_index
		2: # Borderless windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(EnumAutoload.RESOLUTION_ARRAY[GameManager.resolution_index])
			centre_window()
			resolution_option_button.disabled = false
			resolution_option_button.selected = GameManager.resolution_index

func centre_window():
	var screen = DisplayServer.window_get_current_screen()
	var usable_rect = DisplayServer.screen_get_usable_rect(screen)
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(usable_rect.position + (usable_rect.size - window_size) / 2)

func populate_resolution_options() -> void:
	resolution_option_button.clear()
	for resolution in EnumAutoload.RESOLUTION_ARRAY:
		resolution_option_button.add_item("%dx%d" % [resolution.x, resolution.y])

func _on_window_mode_option_button_item_selected(index: int) -> void:
	set_window_mode(index)
	GameManager.window_mode_index = index

func create_keybind_buttons():
	for i in range(keybind_container.get_child_count()):
		if i > 1:
			keybind_container.get_child(i).queue_free()
	InputMap.load_from_project_settings()
	for action in keybindable_action_list:
		var button_inst: KeybindButton = keybind_button_prefab.instantiate()
		keybind_container.add_child(button_inst)
		button_inst.action_label.text = keybindable_action_list[action]
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			button_inst.input_button.text = events[0].as_text().trim_suffix(" (Physical)")
		else:
			button_inst.input_button.text = ""
		button_inst.input_button.pressed.connect(_on_input_button_pressed.bind(button_inst, action))
		button_inst.input_button.mouse_entered.connect(play_button_hover_sfx)


func _on_input_button_pressed(button: KeybindButton, action):
	if not is_remapping:
		is_remapping = true
		action_to_remap = action
		remapping_button = button
		button.input_button.text = "Press key to bind..."

func _on_reset_keybind_button_pressed():
	create_keybind_buttons()


func _on_tab_container_tab_clicked(_tab: int) -> void:
	SoundManager.play_button_click_sfx()

func _on_tab_container_tab_hovered(_tab: int) -> void:
	play_button_hover_sfx()
