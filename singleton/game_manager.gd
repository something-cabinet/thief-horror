extends Node2D

signal first_level_prepared

@export var level_list: Array[PackedScene]
@export var title_screen: PackedScene

var pause_ui: PauseUI
var player: Player
var is_preparing_first_level := false

var cached_first_level: Node

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

const DEFAULT_WINDOW_SCREEN_FRACTION := 0.88
const DEFAULT_WINDOW_ASPECT := 16.0 / 9.0


func _ready() -> void:
    var recommended_size := _configure_screen_aware_window_size()
    if recommended_size == Vector2i.ZERO:
        return

    if DisplayServer.get_name() == "headless":
        _apply_window_size(recommended_size)
    else:
        _apply_window_size_after_first_frame(recommended_size)


func _configure_screen_aware_window_size() -> Vector2i:
    if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
        return Vector2i.ZERO

    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
        return Vector2i.ZERO

    var maximum_size := Vector2i(
        floori(usable_rect.size.x * DEFAULT_WINDOW_SCREEN_FRACTION),
        floori(usable_rect.size.y * DEFAULT_WINDOW_SCREEN_FRACTION)
    )
    var window_width := mini(maximum_size.x, floori(maximum_size.y * DEFAULT_WINDOW_ASPECT))
    window_width -= window_width % 16
    var window_height := floori(window_width * 9.0 / 16.0)
    var recommended_size := Vector2i(window_width, window_height)

    resolution_index = EnumAutoload.configure_resolutions(maximum_size, recommended_size)
    return recommended_size


func _apply_window_size_after_first_frame(recommended_size: Vector2i) -> void:
    # Resizing while Godot's boot splash is still on screen leaves its old
    # Retina framebuffer visible in one quadrant of the resized window.
    await RenderingServer.frame_post_draw
    _apply_window_size(recommended_size)


func _apply_window_size(recommended_size: Vector2i) -> void:
    if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
        return

    DisplayServer.window_set_size(recommended_size)
    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    var decorated_size := DisplayServer.window_get_size_with_decorations()
    DisplayServer.window_set_position(usable_rect.position + (usable_rect.size - decorated_size) / 2)


func prepare_first_level() -> void:
    if cached_first_level != null or is_preparing_first_level or level_list.is_empty():
        return

    is_preparing_first_level = true
    # Let the title screen draw before loading the level in the real gameplay world.
    await get_tree().process_frame

    cached_first_level = level_list[0].instantiate()
    get_tree().root.add_child(cached_first_level)

    var preview_player := cached_first_level.find_child("Player", true, false) as Player
    if preview_player != null:
        preview_player.set_preview_mode(true)
        preview_player.process_mode = Node.PROCESS_MODE_DISABLED
    while preview_player != null and not preview_player.shot_assets_ready:
        await get_tree().process_frame

    # Static collision is already registered in the final World3D. Ground the
    # player before exposing the level as the title background.
    await get_tree().physics_frame
    if preview_player != null:
        preview_player.snap_to_floor()
        preview_player.velocity = Vector3.ZERO
        preview_player.vel_vertical = 0.0

    # Draw one prepared frame behind the title UI before revealing it.
    await get_tree().process_frame
    log_rain_state(cached_first_level, "prepared_main_world")
    is_preparing_first_level = false
    first_level_prepared.emit()

func load_first_level() -> void:
    # Always yield once so callers can draw a loading state before any fallback work.
    await get_tree().process_frame
    if cached_first_level == null:
        prepare_first_level()
        while cached_first_level == null or is_preparing_first_level:
            await get_tree().process_frame

    var previous_scene := get_tree().current_scene
    var preview_player := cached_first_level.find_child("Player", true, false) as Player
    if preview_player != null:
        preview_player.set_preview_mode(false)
        preview_player.process_mode = Node.PROCESS_MODE_INHERIT
    get_tree().current_scene = cached_first_level
    if preview_player != null:
        preview_player.snap_to_floor()
        preview_player.velocity = Vector3.ZERO
        preview_player.vel_vertical = 0.0
    log_rain_state(cached_first_level, "gameplay_enabled")
    set_scene_audio_active(cached_first_level, true)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    cached_first_level = null
    if previous_scene != null:
        previous_scene.queue_free()

func log_rain_state(scene: Node, stage: String) -> void:
    var rain := scene.find_child("Rain", true, false)
    print("[RAIN_DEBUG] game_manager stage=%s scene=%s scene_mode=%d rain_found=%s" % [
        stage,
        scene.get_path(),
        scene.process_mode,
        rain != null,
    ])
    if rain != null and rain.has_method("debug_status"):
        rain.debug_status("game_manager_%s" % stage)

func set_scene_audio_active(node: Node, active: bool) -> void:
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        if active and node.autoplay and not node.playing:
            node.play()
        else:
            if not active:
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
