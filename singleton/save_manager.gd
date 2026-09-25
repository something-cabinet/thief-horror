extends Node

# On Windows, the config file is located in C:\Users\[Name]\AppData\Roaming\Godot\app_userdata\[Project name]

const SETTING_CONFIG_PATH := "user://setting.cfg"

signal setting_config_loaded


func _ready() -> void:
	load_setting_config()


func save_setting_config():
	var config = ConfigFile.new()

	# ConfigFile serializes InputEvents natively, the same way project.godot does.
	for action in SettingUI.KEYBINDABLE_ACTION_LIST:
		if InputMap.has_action(action):
			config.set_value("Keybinding", action, InputMap.action_get_events(action))

	config.set_value("Control", "mouse_sensitivity", GameManager.mouse_sensitivity)
	config.set_value("Graphic", "camera_fov", GameManager.camera_fov)
	config.set_value("Graphic", "camera_tilt", GameManager.camera_tilt)
	config.set_value("Graphic", "fps_limit_index", GameManager.fps_limit_index)
	config.set_value("Graphic", "vsync_option_index", GameManager.vsync_option_index)
	config.set_value("Graphic", "scaling_3d", GameManager.scaling_3d)
	config.set_value("Audio", "master_audio", GameManager.master_audio)
	config.set_value("Audio", "bgm_audio", GameManager.bgm_audio)
	config.set_value("Audio", "sfx_audio", GameManager.sfx_audio)
	config.set_value("Audio", "ui_audio", GameManager.ui_audio)

	config.save(SETTING_CONFIG_PATH)


func load_setting_config():
	var config = ConfigFile.new()

	var err = config.load(SETTING_CONFIG_PATH)

	# If the file didn't load, keep the project defaults.
	if err != OK:
		return

	if config.has_section("Keybinding"):
		for action in config.get_section_keys("Keybinding"):
			var events = config.get_value("Keybinding", action, [])
			if not InputMap.has_action(action) or events.is_empty():
				continue
			InputMap.action_erase_events(action)
			for event in events:
				if event is InputEvent:
					InputMap.action_add_event(action, event)

	GameManager.mouse_sensitivity = config.get_value("Control", "mouse_sensitivity", 50.0)
	GameManager.camera_fov = config.get_value("Graphic", "camera_fov", 90)
	GameManager.camera_tilt = config.get_value("Graphic", "camera_tilt", true)
	GameManager.fps_limit_index = config.get_value("Graphic", "fps_limit_index", 2)
	GameManager.vsync_option_index = config.get_value("Graphic", "vsync_option_index", 1)
	GameManager.scaling_3d = config.get_value("Graphic", "scaling_3d", 100.0)
	GameManager.master_audio = config.get_value("Audio", "master_audio", 80)
	GameManager.bgm_audio = config.get_value("Audio", "bgm_audio", 100)
	GameManager.sfx_audio = config.get_value("Audio", "sfx_audio", 100)
	GameManager.ui_audio = config.get_value("Audio", "ui_audio", 100)

	setting_config_loaded.emit()
