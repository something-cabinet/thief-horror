extends Node2D

@export var level_list: Array[PackedScene]
@export var title_screen: PackedScene

var pause_ui: PauseUI
var player: Player
var is_preparing_first_level := false

var cached_first_level: Node
var warmup_viewport: SubViewport

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


func prepare_first_level() -> void:
    if cached_first_level != null or is_preparing_first_level or level_list.is_empty():
        return

    is_preparing_first_level = true
    await get_tree().process_frame

    warmup_viewport = SubViewport.new()
    warmup_viewport.name = "LevelWarmupViewport"
    warmup_viewport.size = Vector2i(64, 64)
    warmup_viewport.own_world_3d = true
    warmup_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(warmup_viewport)

    cached_first_level = level_list[0].instantiate()
    cached_first_level.process_mode = Node.PROCESS_MODE_DISABLED
    warmup_viewport.add_child(cached_first_level)

    # Allow deferred projectile/particle prewarming to complete offscreen.
    await get_tree().process_frame
    await get_tree().process_frame
    warmup_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    set_scene_audio_active(cached_first_level, false)
    is_preparing_first_level = false

func load_first_level() -> void:
    # Always yield once so callers can draw a loading state before any fallback work.
    await get_tree().process_frame
    if cached_first_level == null:
        prepare_first_level()
        while cached_first_level == null or is_preparing_first_level:
            await get_tree().process_frame

    var previous_scene := get_tree().current_scene
    cached_first_level.reparent(get_tree().root, false)
    cached_first_level.process_mode = Node.PROCESS_MODE_INHERIT
    get_tree().current_scene = cached_first_level
    set_scene_audio_active(cached_first_level, true)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    cached_first_level = null
    if warmup_viewport != null:
        warmup_viewport.queue_free()
        warmup_viewport = null
    if previous_scene != null:
        previous_scene.queue_free()

func set_scene_audio_active(node: Node, active: bool) -> void:
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        if active and node.autoplay:
            node.play()
        else:
            node.stop()
    for child in node.get_children():
        set_scene_audio_active(child, active)

func go_back_to_title_screen():
    get_tree().paused = false
    Engine.time_scale = 1
    reset_data()
    get_tree().change_scene_to_packed(title_screen)


func reset_data():
    pass
