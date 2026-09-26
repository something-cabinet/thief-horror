extends Node3D

const HOUSE_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const PLAYER_SCENE := preload("res://entity/player/Player.tscn")
const OUTPUT_PATH := "res://artifacts/runtime_loot_proof.png"


func _ready() -> void:
	call_deferred("_render_proof")


func _render_proof() -> void:
	get_window().size = Vector2i(1280, 720)
	ProjectSettings.set_setting("thief_horror/runtime_loot_seed", 1337)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.008, 0.014)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.26, 0.28, 0.34)
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var house := HOUSE_SCENE.instantiate()
	add_child(house)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var target_item: PickupItem
	var target_socket: LootSocket
	for child: Node in get_tree().get_nodes_in_group("runtime_loot"):
		var item := child as PickupItem
		if item == null or not house.is_ancestor_of(item):
			continue
		var socket := item.get_parent() as LootSocket
		if (
			socket != null
			and socket.socket_type == "drawer"
		):
			target_item = item
			target_socket = socket
			break
	if target_item == null:
		push_error("[RUNTIME_LOOT_PROOF] drawer item was not found")
		get_tree().quit(1)
		return
	var drawer := target_socket.get_parent() as SlidingInteractable
	drawer.set_open_immediate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var target := target_item.global_position
	var camera_position := _find_pickup_view(player, target_item, drawer)
	if camera_position == Vector3.INF:
		push_error("[RUNTIME_LOOT_PROOF] cabinet item has no player pickup view")
		get_tree().quit(1)
		return
	var camera := player.player_camera.camera
	camera.global_position = camera_position
	camera.look_at(target, Vector3.UP)
	camera.current = true
	camera.near = 0.03

	var flashlight := SpotLight3D.new()
	flashlight.light_color = Color(0.96, 0.92, 0.82)
	flashlight.light_energy = 2.4
	flashlight.spot_range = 8.0
	flashlight.spot_angle = 52.0
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.08, -0.08, -0.1)
	flashlight.rotation = Vector3.ZERO

	player._sync_interaction_outline_camera()
	player._set_focused_interactable(target_item)
	_add_coordinate_label(target_socket)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	get_viewport().get_texture().get_image().save_png(absolute_path)
	print("[RUNTIME_LOOT_PROOF] item=%s position=%s path=%s" % [
		target_item.display_name,
		target_item.global_position,
		absolute_path,
	])
	get_tree().quit()


func _find_pickup_view(
	player: Player,
	item: PickupItem,
	drawer: SlidingInteractable
) -> Vector3:
	var target := item.global_position
	var outward := drawer.slide_axis_world * drawer.open_direction
	var lateral := Vector3.UP.cross(outward).normalized()
	for lateral_offset in [0.0, -0.25, 0.25]:
		for height in [0.45, 0.75, 1.05, 1.35, 1.65]:
			var ray_start: Vector3 = (
				target
				+ outward * 1.2
				+ lateral * lateral_offset
				+ Vector3.UP * height
			)
			if player._find_visible_interactable(ray_start, target) == item:
				return ray_start
	return Vector3.INF


func _add_coordinate_label(socket: LootSocket) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(18.0, 674.0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = "(%.2f, %.2f, %.2f)" % [
		socket.global_position.x,
		socket.global_position.y,
		socket.global_position.z,
	]
	layer.add_child(label)
