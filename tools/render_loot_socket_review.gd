extends SceneTree

const HOUSE_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const HOUSE_LOOT_SPAWNER := preload("res://entity/item/house_loot_spawner.gd")
const OUTPUT_DIRECTORY := "res://artifacts/loot_socket_review"
const HOUSE_CENTER := Vector3(-38.5, 0.5, -127.5)
const CONTEXT_PREFIXES := [
	"Al_", "Anaquel", "Closet", "Cofre", "Estante", "Estanteria",
	"Librero", "Mesa", "Puerta_R", "Refrigerador", "P_", "p_",
]
const DRAWER_CONTAINERS := {
	&"P_001": &"Cofre",
	&"p_007": &"Cofre_001",
	&"p_009": &"Al_009",
	&"p_010": &"Estante",
	&"p_011": &"Estante",
	&"p_012": &"Estante",
	&"p_013": &"Estante",
	&"p_018": &"Mesa_010",
	&"p_021": &"Closet_002",
	&"p_022": &"Mesa_012",
	&"p_038": &"Mesa_014",
	&"p_042": &"Mesa_Trabajo",
	&"p_043": &"Mesa_Trabajo",
	&"p_048": &"Mesa_011",
	&"p_049": &"Al_010",
	&"p_050": &"Al_010",
	&"p_051": &"Closet_003",
	&"p_058": &"Mesa_015",
}
var house: Node3D
var camera: Camera3D
var review_items: Array[Node3D] = []
var translucent_states: Array[Dictionary] = []
var detail_label: Label
var single_drawer_mode := false


func _initialize() -> void:
	call_deferred("_render_review")


func _render_review() -> void:
	root.size = Vector2i(960, 720)
	ProjectSettings.set_setting("thief_horror/disable_runtime_loot", true)
	house = HOUSE_SCENE.instantiate()
	root.add_child(house)
	_add_review_lighting()
	_add_review_hud()
	camera = Camera3D.new()
	camera.fov = 54.0
	root.add_child(camera)
	camera.current = true
	await process_frame
	await physics_frame
	await process_frame
	var socket_groups := _group_sockets_by_furniture()
	single_drawer_mode = "--single-drawer" in OS.get_cmdline_user_args()
	var source_filter := _source_filter_argument()
	var source_paths: Array[String] = []
	for source_path: String in socket_groups:
		var sockets: Array = socket_groups[source_path]
		var source := root.get_node_or_null(NodePath(source_path))
		if source_filter != "" and (source == null or String(source.name) != source_filter):
			continue
		if single_drawer_mode:
			if (
				String(sockets[0].get("socket_type")) != "drawer"
				or source == null
				or source.name != &"Mesa_011"
			):
				continue
		source_paths.append(source_path)
		if single_drawer_mode:
			break
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(output_path)
	var output_directory := DirAccess.open(output_path)
	if output_directory != null and not single_drawer_mode and source_filter == "":
		for file_name: String in output_directory.get_files():
			if file_name.ends_with(".png"):
				output_directory.remove(file_name)
	var source_index := 0
	var rendered_item_count := 0
	for source_path: String in source_paths:
		var sockets: Array = socket_groups[source_path]
		var source := root.get_node_or_null(NodePath(source_path))
		_close_all_moving_parts()
		_show_loot_items(sockets)
		_frame_sockets(sockets, source)
		_update_review_hud(source, sockets, source_index, source_paths.size())
		rendered_item_count += review_items.size()
		await process_frame
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var source_name := "unknown" if source == null else String(source.name)
		var type := String(sockets[0].get("socket_type"))
		var file_name := (
			"drawer_translucency_proof.png"
			if single_drawer_mode
			else "%03d_%s_%s.png" % [
				source_index,
				_safe_name(type),
				_safe_name(source_name),
			]
		)
		root.get_texture().get_image().save_png(output_path.path_join(file_name))
		source_index += 1

	if rendered_item_count == 0:
		push_error("[LOOT_REVIEW] no randomized loot was rendered")
		quit(1)
		return
	print("[LOOT_REVIEW] views=%d real_items=%d directory=%s" % [
		source_index,
		rendered_item_count,
		output_path,
	])
	quit()


func _source_filter_argument() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			return argument.trim_prefix("--source=")
	return ""


func _group_sockets_by_furniture() -> Dictionary:
	var result := {}
	for socket: Node in get_nodes_in_group("loot_socket"):
		var furniture := _furniture_for_socket(socket)
		var furniture_path := (
			String(socket.get_path())
			if furniture == null
			else String(furniture.get_path())
		)
		if not result.has(furniture_path):
			result[furniture_path] = []
		result[furniture_path].append(socket)
	return result


func _furniture_for_socket(socket: Node) -> Node3D:
	var source_path: NodePath = socket.get("source_node")
	var source := root.get_node_or_null(source_path) as Node3D
	var socket_type := String(socket.get("socket_type"))
	if socket_type == "fridge":
		return house.find_child("Refrigerador", true, false) as Node3D
	if socket_type != "drawer" or source is not SlidingInteractable:
		return source
	var drawer_meshes := source.find_children("*", "MeshInstance3D", true, false)
	if drawer_meshes.is_empty():
		return source
	var part_name: StringName = (drawer_meshes[0] as MeshInstance3D).name
	var container_name: StringName = DRAWER_CONTAINERS.get(part_name, &"")
	var container := house.find_child(container_name, true, false) as Node3D
	return source if container == null else container


func _show_loot_items(sockets: Array) -> void:
	for item in review_items:
		item.free()
	review_items.clear()
	HOUSE_LOOT_SPAWNER.spawn_for_sockets(sockets)
	for socket: Node3D in sockets:
		for child: Node in socket.get_children():
			if child is Node3D and child.is_in_group("runtime_loot"):
				var item := child as Node3D
				item.visible = true
				review_items.append(item)


func _frame_sockets(sockets: Array, source: Node) -> void:
	for state: Dictionary in translucent_states:
		var old_mesh := state.mesh as MeshInstance3D
		if is_instance_valid(old_mesh):
			old_mesh.material_override = state.material_override
			old_mesh.transparency = state.transparency
	translucent_states.clear()
	_close_all_moving_parts()
	var socket_type := String(sockets[0].get("socket_type"))
	var has_closed_storage := false
	for socket: Node3D in sockets:
		if String(socket.get("socket_type")) in ["cabinet", "wardrobe"]:
			has_closed_storage = true
		var socket_source_path: NodePath = socket.get("source_node")
		var socket_source := root.get_node_or_null(socket_source_path)
		if socket_source is MovingInteractable:
			(socket_source as MovingInteractable).set_open_immediate(true, 1.0)
	if has_closed_storage and source is MeshInstance3D:
		var source_mesh := source as MeshInstance3D
		var source_bounds := (source_mesh.global_transform * source_mesh.get_aabb()).grow(0.52)
		for child: Node in house.find_children("*", "HingedInteractable", true, false):
			var cabinet_door := child as HingedInteractable
			if cabinet_door.display_name != "cabinet door":
				continue
			cabinet_door.set_open_immediate(false)
			var door_center := cabinet_door.to_global(cabinet_door.moving_collision.position)
			if source_bounds.has_point(door_center):
				cabinet_door.set_open_immediate(true, 1.0)
	if source != null and source.name == &"Refrigerador":
		for child: Node in house.find_children("*", "MovingInteractable", true, false):
			var moving := child as MovingInteractable
			if moving.display_name in ["freezer door", "refrigerator door"]:
				moving.set_open_immediate(true, 1.0)
	_make_whole_item_translucent(source, sockets, has_closed_storage)
	var center := Vector3.ZERO
	for socket: Node3D in sockets:
		center += socket.global_position
	center /= float(sockets.size())

	var radius := 0.45
	var item_bounds := _translucent_item_bounds()
	if item_bounds.size != Vector3.ZERO:
		center = item_bounds.get_center()
		radius = maxf(radius, item_bounds.size.length() * 0.5)
	for socket: Node3D in sockets:
		radius = maxf(radius, socket.global_position.distance_to(center))
	_show_nearby_context(center, source, socket_type)
	var minimum_distance: float = {
		"drawer": 0.9,
		"fridge": 1.15,
		"cabinet": 1.35,
		"wardrobe": 1.8,
		"shelf": 1.5,
		"table": 1.5,
	}.get(socket_type, 1.5)
	var distance := clampf(radius * 2.15 + 0.25, minimum_distance, 12.0)
	var horizontal_view := _front_view_direction(center, source, socket_type)
	if single_drawer_mode and socket_type == "drawer":
		var side_view := Vector3(-horizontal_view.z, 0.0, horizontal_view.x)
		horizontal_view = (horizontal_view + side_view * 0.5).normalized()
		distance = maxf(distance, 1.25)
	var height_ratio := 0.48 if socket_type == "drawer" else 0.44
	camera.global_position = center + horizontal_view * distance + Vector3.UP * distance * height_ratio
	camera.look_at(center, Vector3.UP)
	camera.near = 0.03
	camera.far = 80.0


func _close_all_moving_parts() -> void:
	for child: Node in house.find_children("*", "MovingInteractable", true, false):
		(child as MovingInteractable).set_open_immediate(false)


func _translucent_item_bounds() -> AABB:
	var result := AABB()
	var has_bounds := false
	for state: Dictionary in translucent_states:
		var mesh := state.mesh as MeshInstance3D
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		result = bounds if not has_bounds else result.merge(bounds)
		has_bounds = true
	return result


func _make_source_translucent(source: Node) -> void:
	if source == null:
		return
	if source is MeshInstance3D:
		_make_mesh_translucent(source as MeshInstance3D)
	for child: Node in source.find_children("*", "MeshInstance3D", true, false):
		if _has_runtime_loot_ancestor(child):
			continue
		_make_mesh_translucent(child as MeshInstance3D)


func _has_runtime_loot_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current.is_in_group("runtime_loot"):
			return true
		current = current.get_parent()
	return false


func _make_whole_item_translucent(
	source: Node,
	sockets: Array,
	has_closed_storage: bool
) -> void:
	if source == null:
		return
	_make_source_translucent(source)
	for socket: Node3D in sockets:
		var socket_source_path: NodePath = socket.get("source_node")
		var socket_source := root.get_node_or_null(socket_source_path)
		if socket_source is MovingInteractable:
			_make_source_translucent(socket_source)
	if not has_closed_storage or source is not MeshInstance3D:
		return
	var source_mesh := source as MeshInstance3D
	var source_bounds := (source_mesh.global_transform * source_mesh.get_aabb()).grow(0.52)
	for child: Node in house.find_children("*", "HingedInteractable", true, false):
		var door := child as HingedInteractable
		if door.display_name != "cabinet door":
			continue
		door.set_open_immediate(false)
		var door_center := door.to_global(door.moving_collision.position)
		door.set_open_immediate(true, 1.0)
		if source_bounds.has_point(door_center):
			_make_source_translucent(door)

func _make_mesh_translucent(mesh: MeshInstance3D) -> void:
	for state: Dictionary in translucent_states:
		if state.mesh == mesh:
			return
	translucent_states.append({
		"mesh": mesh,
		"material_override": mesh.material_override,
		"transparency": mesh.transparency,
	})
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.18, 0.72, 0.95, 0.2)
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.22, 0.3)
	glass.emission_energy_multiplier = 0.7
	glass.roughness = 0.25
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.render_priority = 1
	mesh.material_override = glass
	mesh.transparency = 0.0


func _show_nearby_context(center: Vector3, source: Node, socket_type: String) -> void:
	for child: Node in house.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		if _has_runtime_loot_ancestor(mesh):
			continue
		var is_whole_item_mesh := false
		for state: Dictionary in translucent_states:
			if state.mesh == mesh:
				is_whole_item_mesh = true
				break
		mesh.visible = is_whole_item_mesh


func _front_view_direction(center: Vector3, source: Node, socket_type: String) -> Vector3:
	if source is SlidingInteractable:
		var drawer := source as SlidingInteractable
		var opening_direction := drawer.slide_axis_world * drawer.open_direction
		opening_direction.y = 0.0
		if not opening_direction.is_zero_approx():
			return opening_direction.normalized()
	if socket_type in ["cabinet", "wardrobe"]:
		var nearest_door_direction := Vector3.ZERO
		var nearest_door_distance := INF
		for child: Node in house.find_children("*", "HingedInteractable", true, false):
			var door := child as HingedInteractable
			if door.display_name != "cabinet door":
				continue
			door.set_open_immediate(false)
			var closed_center := door.to_global(door.moving_collision.position)
			door.set_open_immediate(true, 1.0)
			var distance := closed_center.distance_squared_to(center)
			if distance < nearest_door_distance:
				nearest_door_distance = distance
				nearest_door_direction = closed_center - center
		nearest_door_direction.y = 0.0
		if not nearest_door_direction.is_zero_approx():
			return nearest_door_direction.normalized()
	var horizontal_size := Vector2.ZERO
	if source is MeshInstance3D:
		var bounds := (source as MeshInstance3D).global_transform * (source as MeshInstance3D).get_aabb()
		horizontal_size = Vector2(bounds.size.x, bounds.size.z)
	elif source is MovingInteractable:
		var moving := source as MovingInteractable
		var box := moving.moving_collision.shape as BoxShape3D
		if box != null:
			horizontal_size = Vector2(box.size.x, box.size.z)

	if horizontal_size == Vector2.ZERO or absf(horizontal_size.x - horizontal_size.y) < 0.12:
		return Vector3(0.72, 0.0, 1.0).normalized()
	var axis := Vector3.RIGHT if horizontal_size.x < horizontal_size.y else Vector3.FORWARD
	var toward_house := HOUSE_CENTER - center
	if toward_house.dot(axis) < 0.0:
		axis = -axis
	return axis


func _add_review_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.028, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 1.0)
	environment.ambient_light_energy = 1.25
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	root.add_child(light)


func _add_review_hud() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	detail_label = Label.new()
	detail_label.position = Vector2(24.0, 680.0)
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.add_theme_color_override("font_color", Color.WHITE)
	detail_label.add_theme_color_override("font_outline_color", Color.BLACK)
	detail_label.add_theme_constant_override("outline_size", 7)
	canvas.add_child(detail_label)


func _update_review_hud(
	source: Node,
	sockets: Array,
	view_index: int,
	view_count: int
) -> void:
	var socket_type := String(sockets[0].get("socket_type"))
	var furniture_position := Vector3.ZERO if source == null else (source as Node3D).global_position
	if source is SlidingInteractable and socket_type == "drawer":
		var drawer_meshes := source.find_children("*", "MeshInstance3D", true, false)
		if not drawer_meshes.is_empty():
			var part_name: StringName = (drawer_meshes[0] as MeshInstance3D).name
			var container_name: StringName = DRAWER_CONTAINERS.get(part_name, &"")
			var container := house.find_child(container_name, true, false) as MeshInstance3D
			if container != null:
				furniture_position = container.global_position
	elif socket_type == "fridge":
		var refrigerator := house.find_child("Refrigerador", true, false) as MeshInstance3D
		if refrigerator != null:
			furniture_position = refrigerator.global_position
	detail_label.text = "(%.2f, %.2f, %.2f)" % [
		furniture_position.x,
		furniture_position.y,
		furniture_position.z,
	]


func _safe_name(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", "/", "\\", ":", "."]:
		result = result.replace(character, "_")
	return result
