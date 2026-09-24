extends Node2D

@export var level_list: Array[PackedScene]
@export var title_screen: PackedScene

var pause_ui: PauseUI
var player: Player

# Setting
var mouse_sensitivity: float = 50.0
var camera_fov: float = 90: # From 60 to 120
    set(value):
        if value != camera_fov and is_instance_valid(player):
            player.player_camera.set_fov(value)
        camera_fov = value
var camera_tilt = true
var fps_limit_index = 2 # From 0 to 5. Refer to EnumAutoload.FPS_LIMIT_ARRAY
var resolution_index = 4 # From 0 to 6. Refer to EnumAutoload.RESOLUTION_ARRAY. Not used in FULL_SCREEN
var vsync_option_index = 1
var window_mode_index = 1 # From 0 to 2
var scaling_3d = 100.0
var master_audio = 80
var bgm_audio = 100
var sfx_audio = 100
var ui_audio = 100


func load_first_level():
    get_tree().change_scene_to_packed(level_list[0])

func go_back_to_title_screen():
    get_tree().paused = false
    Engine.time_scale = 1
    reset_data()
    get_tree().change_scene_to_packed(title_screen)


func reset_data():
    pass
