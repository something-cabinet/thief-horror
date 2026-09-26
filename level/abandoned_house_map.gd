extends Node3D

const LOOT_SOCKET_SCRIPT := preload("res://entity/item/loot_socket.gd")
const HOUSE_LOOT_SPAWNER := preload("res://entity/item/house_loot_spawner.gd")
const TELEVISION_SCREEN_SHADER := preload("res://material/television_screen.gdshader")
const BLACKBOARD_PLAN_TEXTURE := preload("res://asset/texture/blackboard_robbery_plan.png")
const BLACKBOARD_CHALK_SHADER := preload("res://material/blackboard_chalk_overlay.gdshader")
const FRONT_DOOR_STAGING_OFFSET := Vector3(19.816, 0.0, 0.0)
const RED_SIDE_DOOR_FRAME := &"Marco_P_013"
const RED_SIDE_DOOR_COLOR := Color(0.82, 0.055, 0.035, 1.0)
const FOOTSTEP_AREA_LAYER := 1 << 4

const STRUCTURE_COLLISION_PREFIXES := [
	"Casa",
	"Piso",
	"Patio",
	"Pared",
	"Muro",
	"Carretera",
	"Escalera",
	"Plane",
	"Fondo",
	"Columnas",
	"Pizarra",
	"Poste_Luz",
	"Barandal",
	"Bigas",
	"Pisina",
]
const COLLISION_EXACT_NAMES := ["E"]
const EXACT_PROP_COLLISION_PREFIXES := ["Mesa"]
const STATIC_CABINET_PARTS := [&"P", &"p_008", &"p_023", &"p_024", &"p_041"]
const DRAWER_PARTS := [
	&"P_001", &"p_007", &"p_009", &"p_010", &"p_011", &"p_012",
	&"p_013", &"p_018", &"p_021", &"p_022", &"p_038", &"p_042",
	&"p_043", &"p_048", &"p_049", &"p_050", &"p_051", &"p_058",
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
const FORCE_CLOSED_DRAWERS := [&"P_001", &"p_007"]
const TELEVISION_MESH_NAMES := [&"Tele", &"Tele_001", &"Tele_002", &"Tele_003"]
const TELEVISION_SCREEN_RECTS := {
	# The screen areas inside the original Tele2.jpg and Tele1.jpg atlases.
	&"Tele": Vector4(0.137, 0.198, 0.867, 0.775),
	&"Tele_001": Vector4(0.078, 0.116, 0.703, 0.860),
	&"Tele_002": Vector4(0.078, 0.116, 0.703, 0.860),
	&"Tele_003": Vector4(0.078, 0.116, 0.703, 0.860),
}
const TELEVISION_SCREEN_MASKS := {
	&"Tele": preload("res://asset/model/abandoned_house/tv_screen_mask_tele2.svg"),
	&"Tele_001": preload("res://asset/model/abandoned_house/tv_screen_mask_tele1.svg"),
	&"Tele_002": preload("res://asset/model/abandoned_house/tv_screen_mask_tele1.svg"),
	&"Tele_003": preload("res://asset/model/abandoned_house/tv_screen_mask_tele1.svg"),
}
const TELEVISION_FRONT_NORMALS := {
	&"Tele": Vector3.LEFT,
	&"Tele_001": Vector3.FORWARD,
	&"Tele_002": Vector3.RIGHT,
	&"Tele_003": Vector3.BACK,
}
const SOLID_PROP_PREFIXES := [
	"Anaquel",
	"Barril",
	"Bañera",
	"Bote_Basura",
	"Bote_basura",
	"Caja",
	"Cama",
	"Cesta",
	"Closet",
	"Cofre",
	"Colchon",
	"Estante",
	"Estanteria",
	"Estufa",
	"Generador",
	"Lavabo",
	"Lavadero",
	"Lavadora",
	"Librero",
	"Mesa",
	"Refrigerador",
	"Secadora",
	"Silla",
	"Sillon",
	"Tasa_Baño",
	"Tasa_baño",
	"Tele",
]
const LAMP_PREFIXES := ["Lampara", "Foco"]
const LAMP_MATERIALS := ["Lampara1", "Lampara2", "Lampara3.001", "Foco"]
const LOOT_STORAGE_PREFIXES := [
	"Al_", "Closet", "Cofre", "Estante", "Librero", "Mesa",
]
const LOOT_SHELF_PREFIXES := ["Estanteria", "Librero"]
const LOOT_EXCLUDED_STORAGE: Array[StringName] = []


func _ready() -> void:
	_move_staging_to_front_door()
	_fix_invalid_imported_materials()
	_fix_imported_carpet_materials()
	_fix_imported_glass()
	_setup_blackboard_plan()
	_setup_front_door()
	_setup_red_side_door()
	_setup_refrigerator_doors()
	_setup_van_doors()
	_setup_cabinet_parts()
	_setup_loot_sockets()
	_setup_laundry_lids()
	_setup_interactable_televisions()
	_setup_interactable_lights()
	var structure_count := 0
	var prop_count := 0
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or _has_interactable_ancestor(mesh_instance):
			continue
		var footstep_surface := _footstep_surface_for_mesh(mesh_instance)
		if footstep_surface == &"carpet":
			_setup_footstep_area(mesh_instance, footstep_surface)

		var is_solid_prop := (
			mesh_instance.name == &"Ban"
			or mesh_instance.name in STATIC_CABINET_PARTS
			or _matches_prefix(mesh_instance.name, SOLID_PROP_PREFIXES)
		)
		var is_structure := _needs_structure_collision(mesh_instance.name)
		var uses_exact_prop_collision := (
			mesh_instance.name in [&"Ban", &"Cofre", &"Refrigerador"]
			or _matches_prefix(mesh_instance.name, EXACT_PROP_COLLISION_PREFIXES)
			or _matches_prefix(mesh_instance.name, LOOT_STORAGE_PREFIXES)
			or _matches_prefix(mesh_instance.name, LOOT_SHELF_PREFIXES)
		)
		if not is_solid_prop and not is_structure:
			continue

		var body := StaticBody3D.new()
		body.name = "%sCollision" % mesh_instance.name
		body.set_meta(&"footstep_surface", footstep_surface)
		var collision := CollisionShape3D.new()
		if is_solid_prop and not uses_exact_prop_collision:
			var bounds := mesh_instance.mesh.get_aabb()
			var box := BoxShape3D.new()
			box.size = bounds.size
			collision.position = bounds.get_center()
			collision.shape = box
			prop_count += 1
		else:
			var shape := mesh_instance.mesh.create_trimesh_shape()
			if shape == null:
				continue
			collision.shape = shape
			if is_solid_prop:
				prop_count += 1
			else:
				structure_count += 1
		mesh_instance.add_child(body)
		body.add_child(collision)
	print("Abandoned house collision ready: %d structures, %d solid props" % [
		structure_count,
		prop_count,
	])
	if not bool(ProjectSettings.get_setting("thief_horror/disable_runtime_loot", false)):
		call_deferred("_spawn_runtime_loot")


func _spawn_runtime_loot() -> void:
	# Wait until imported furniture collision is live before rejecting sockets
	# hidden inside unrelated props such as crates and televisions.
	await get_tree().physics_frame
	var loot_count: int = HOUSE_LOOT_SPAWNER.spawn_for_house(self)
	print("Runtime house loot ready: %d collectible items" % loot_count)


func _move_staging_to_front_door() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		push_warning("Abandoned house model was not found")
		return
	for node_name: StringName in [&"Ban", &"Base"]:
		var staging_node := model.get_node_or_null(NodePath(node_name)) as Node3D
		if staging_node == null:
			push_warning("Abandoned house staging node %s was not found" % node_name)
			continue
		staging_node.position += FRONT_DOOR_STAGING_OFFSET


func _setup_blackboard_plan() -> void:
	var board := find_child("Pizarra", true, false) as MeshInstance3D
	if board == null or board.mesh == null:
		push_warning("Abandoned house blackboard mesh was not found")
		return

	# Use only the four vertices carrying the green "Pizarra" material. The
	# mesh AABB also contains the wooden frame and legs and is not a writing area.
	var surface_bounds := AABB()
	var found_surface := false
	for surface_index in board.mesh.get_surface_count():
		var material := board.get_active_material(surface_index)
		if material == null or material.resource_name != "Pizarra":
			continue
		var arrays := board.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		surface_bounds = AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			surface_bounds = surface_bounds.expand(vertex)
		found_surface = true
		break
	if not found_surface:
		push_warning("Abandoned house blackboard writing surface was not found")
		return

	var surface_center := board.to_global(surface_bounds.get_center())
	var front := -board.global_basis.x.normalized()
	var right := -board.global_basis.y.normalized()
	var up := board.global_basis.z.normalized()
	var writing_basis := Basis(right, up, front).orthonormalized()
	var surface_width := surface_bounds.size.y * board.global_basis.y.length()
	var surface_height := surface_bounds.size.z * board.global_basis.z.length()
	var left_edge := surface_center - right * surface_width * 0.5
	var text_surface := front * 0.004
	var horizontal_padding := 0.10
	var available_width := surface_width - horizontal_padding * 2.0

	var chalk_font := SystemFont.new()
	chalk_font.font_names = PackedStringArray([
		"Chalkduster",
		"Chalkboard SE",
		"Comic Sans MS",
		"Comic Sans",
	])

	var heading_text := "REMEMBER, IDIOT"
	var heading_font_size := 48
	var heading_pixel_width := chalk_font.get_string_size(
		heading_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		heading_font_size
	).x
	var heading_pixel_size := minf(0.00165, available_width / heading_pixel_width)
	var heading := _make_blackboard_label(
		heading_text,
		chalk_font,
		heading_font_size,
		heading_pixel_size
	)
	add_child(heading)
	var heading_world_width := heading_pixel_width * heading_pixel_size
	heading.global_transform = Transform3D(
		writing_basis,
		surface_center - right * heading_world_width * 0.5
			+ up * surface_height * 0.36 + text_surface
	)

	var plan_lines := [
		"STUFFS — AROUND THE HOUSE?",
		"CELLAR — KEEP SHUT",
		"IF HE CALLS, DON’T ANSWER",
	]
	var body_font_size := 36
	var maximum_line_width := 1.0
	for line in plan_lines:
		maximum_line_width = maxf(
			maximum_line_width,
			chalk_font.get_string_size(
				line,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				body_font_size
			).x
		)
	var text_column_width := surface_width * 0.43
	var body_pixel_size := minf(0.0019, text_column_width / maximum_line_width)
	var line_step := surface_height * 0.16
	for line_index in plan_lines.size():
		var line := _make_blackboard_label(
			plan_lines[line_index],
			chalk_font,
			body_font_size,
			body_pixel_size
		)
		add_child(line)
		line.global_transform = Transform3D(
			writing_basis,
			left_edge + right * horizontal_padding
				+ up * (surface_height * 0.13 - line_step * line_index)
				+ text_surface
		)

	var overlay_width := surface_width * 0.46
	var overlay_height := (
		overlay_width
		* float(BLACKBOARD_PLAN_TEXTURE.get_height())
		/ float(BLACKBOARD_PLAN_TEXTURE.get_width())
	)
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = BLACKBOARD_CHALK_SHADER
	overlay_material.set_shader_parameter("chalk_texture", BLACKBOARD_PLAN_TEXTURE)
	overlay_material.set_shader_parameter(
		"chalk_color",
		Color(0.93, 0.91, 0.78, 0.78)
	)
	var overlay_quad := QuadMesh.new()
	overlay_quad.size = Vector2(overlay_width, overlay_height)
	overlay_quad.material = overlay_material
	var overlay := MeshInstance3D.new()
	overlay.name = "BlackboardRobberyDrawing"
	overlay.mesh = overlay_quad
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay)
	overlay.global_transform = Transform3D(
		writing_basis,
		surface_center + right * surface_width * 0.22
			- up * surface_height * 0.10 + text_surface
	)


func _make_blackboard_label(
	text: String,
	font: Font,
	font_size: int,
	pixel_size: float
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color(0.93, 0.91, 0.78, 0.92)
	label.outline_size = 2
	label.outline_modulate = Color(0.08, 0.12, 0.08, 0.55)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.width = font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x + 4.0
	label.double_sided = false
	label.no_depth_test = false
	return label


func _setup_front_door() -> void:
	var door_mesh := find_child("Puerta", true, false) as MeshInstance3D
	if door_mesh == null or door_mesh.mesh == null or door_mesh.get_parent().name != &"Casa":
		push_warning("Abandoned house front door mesh was not found")
		return
	var closed_mesh_transform := door_mesh.global_transform
	var closed_world_bounds := closed_mesh_transform * door_mesh.get_aabb()
	var door := InteractableDoor.new()
	door.name = "FrontDoor"
	add_child(door)
	door.global_transform = Transform3D(Basis.IDENTITY, closed_mesh_transform.origin)
	door_mesh.reparent(door, true)
	door.configure_collision(closed_world_bounds, closed_mesh_transform.origin)


func _setup_red_side_door() -> void:
	var source_mesh := find_child("Puerta", true, false) as MeshInstance3D
	var frame := find_child(RED_SIDE_DOOR_FRAME, true, false) as MeshInstance3D
	if source_mesh == null or source_mesh.mesh == null or frame == null or frame.mesh == null:
		push_warning("Red side door source mesh or doorway frame was not found")
		return

	var source_transform := source_mesh.global_transform
	var source_bounds := _world_bounds(source_mesh)
	var quarter_turn := Basis(Vector3.UP, deg_to_rad(90.0))
	var frame_center := _world_bounds(frame).get_center()
	var source_center_offset := source_bounds.get_center() - source_transform.origin

	var red_mesh := source_mesh.duplicate() as MeshInstance3D
	red_mesh.name = "RedSideDoorMesh"
	add_child(red_mesh)
	red_mesh.global_transform = Transform3D(
		quarter_turn * source_transform.basis,
		frame_center - quarter_turn * source_center_offset
	)
	for surface_index in red_mesh.mesh.get_surface_count():
		var source_material := red_mesh.get_active_material(surface_index)
		if source_material is StandardMaterial3D:
			var red_material := source_material.duplicate() as StandardMaterial3D
			red_material.resource_name = "RedDoor"
			red_material.albedo_color = RED_SIDE_DOOR_COLOR
			red_material.roughness = 0.88
			red_mesh.set_surface_override_material(surface_index, red_material)

	var closed_bounds := _world_bounds(red_mesh)
	var door := InteractableDoor.new()
	door.name = "RedSideDoor"
	door.display_name = "Red door"
	add_child(door)
	door.global_transform = Transform3D(Basis.IDENTITY, red_mesh.global_position)
	red_mesh.reparent(door, true)
	door.configure_collision(closed_bounds, door.global_position)


func _setup_refrigerator_doors() -> void:
	var door_index := 0
	for mesh in _find_meshes(&"Casa", "Puerta_R"):
		var label := "freezer door" if door_index == 0 else "refrigerator door"
		_wrap_vertical_hinge(mesh, label, 105.0)
		door_index += 1


func _setup_van_doors() -> void:
	var van_mesh := find_child("Ban", true, false) as MeshInstance3D
	if van_mesh == null:
		push_warning("Abandoned house van mesh was not found")
		return
	var van_center := _world_bounds(van_mesh).get_center()
	for mesh in _find_meshes(&"Ban", "Puerta_"):
		var label := "van door"
		if String(mesh.name).begins_with("Puerta_Late"):
			label = "van side door"
		elif String(mesh.name).begins_with("Puerta_Tra"):
			label = "van rear door"
		var open_angle := 72.0 if label == "van door" else 95.0
		var door := _wrap_vertical_hinge(mesh, label, open_angle)
		door.choose_direction_from_actor = false
		door.open_direction = (
			1.0
			if door._open_center_for_direction(1.0).distance_squared_to(van_center)
			>= door._open_center_for_direction(-1.0).distance_squared_to(van_center)
			else -1.0
		)


func _setup_cabinet_parts() -> void:
	for mesh in _find_meshes(&"Cajones_Puertas", ""):
		if mesh.name in STATIC_CABINET_PARTS:
			continue
		var bounds := _world_bounds(mesh)
		if mesh.name not in DRAWER_PARTS:
			_wrap_vertical_hinge(mesh, "cabinet door", 95.0)
			continue
		var container_name: StringName = DRAWER_CONTAINERS.get(mesh.name, &"")
		var container := find_child(container_name, true, false) as MeshInstance3D
		var slide_axis := _horizontal_depth_axis(container)
		if slide_axis.is_zero_approx():
			slide_axis = Vector3.RIGHT if bounds.size.x <= bounds.size.z else Vector3.FORWARD
		var drawer := _wrap_slider(mesh, "drawer", slide_axis, 0.35, false, 1.0)
		_configure_imported_drawer(
			drawer,
			bounds,
			container,
			mesh.name in FORCE_CLOSED_DRAWERS
		)


func _setup_loot_sockets() -> void:
	_setup_drawer_loot_sockets()
	_setup_closed_storage_loot_sockets()
	_setup_refrigerator_loot_sockets()
	_setup_shelf_loot_sockets()
	_setup_table_loot_sockets()
	print("House loot sockets ready: %d" % get_tree().get_nodes_in_group("loot_socket").size())


func _setup_drawer_loot_sockets() -> void:
	for child: Node in find_children("*", "SlidingInteractable", true, false):
		var drawer := child as SlidingInteractable
		if drawer.display_name != "drawer" or drawer.moving_collision == null:
			continue
		var box := drawer.moving_collision.shape as BoxShape3D
		if box == null:
			continue
		var local_position := drawer.moving_collision.position
		local_position.y -= box.size.y * 0.28
		var drawer_meshes := drawer.find_children("*", "MeshInstance3D", true, false)
		if not drawer_meshes.is_empty():
			var surface_levels := _upward_surface_levels(
				drawer_meshes[0] as MeshInstance3D
			)
			if not surface_levels.is_empty():
				var current_world_y := drawer.to_global(local_position).y
				var nearest_surface_y: float = surface_levels[0]
				for surface_y: float in surface_levels:
					if absf(surface_y - current_world_y) < absf(
						nearest_surface_y - current_world_y
					):
						nearest_surface_y = surface_y
				local_position.y += nearest_surface_y - current_world_y
		var usable_size := Vector3(
			maxf(0.12, box.size.x * 0.66),
			maxf(0.08, box.size.y * 0.34),
			maxf(0.12, box.size.z * 0.66)
		)
		_add_loot_socket(
			drawer,
			local_position,
			"drawer",
			usable_size,
			drawer
		)


func _setup_closed_storage_loot_sockets() -> void:
	var containers: Array[MeshInstance3D] = []
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if (
			mesh.mesh != null
			and mesh.name not in LOOT_EXCLUDED_STORAGE
			and _matches_prefix(mesh.name, LOOT_STORAGE_PREFIXES)
		):
			containers.append(mesh)

	var matched := {}
	for child: Node in find_children("*", "HingedInteractable", true, false):
		var door := child as HingedInteractable
		if door.display_name != "cabinet door" or door.moving_collision == null:
			continue
		var door_center := door.to_global(door.moving_collision.position)
		var container := _nearest_storage_container(door_center, containers)
		if container != null:
			# Each independently openable door gets its own populated compartment.
			# Grouping every door on a large bookshelf/table into one socket left
			# the other visible cavities empty.
			matched[door.get_instance_id()] = {
				"container": container,
				"doors": [door],
			}

	for record: Dictionary in matched.values():
		var container := record.container as MeshInstance3D
		var doors: Array = record.doors
		var bounds := _world_bounds(container)
		var type := "wardrobe" if String(container.name).begins_with("Closet") else "cabinet"
		var primary_door := doors[0] as HingedInteractable
		var primary_distance := INF
		for door_node: Node in doors:
			var door := door_node as HingedInteractable
			var door_center := door.to_global(door.moving_collision.position)
			var closest := Vector3(
				clampf(door_center.x, bounds.position.x, bounds.end.x),
				clampf(door_center.y, bounds.position.y, bounds.end.y),
				clampf(door_center.z, bounds.position.z, bounds.end.z)
			)
			var distance := closest.distance_to(door_center)
			if distance < primary_distance:
				primary_distance = distance
				primary_door = door
		var primary_box := primary_door.moving_collision.shape as BoxShape3D
		var opening_center := primary_door.to_global(
			primary_door.moving_collision.position
		)
		var horizontal_lid := (
			primary_box.size.y
			< minf(primary_box.size.x, primary_box.size.z) * 0.35
		)
		var support_y := opening_center.y - primary_box.size.y * 0.30
		# The imported container AABB includes feet and trim below the usable
		# opening. Place loot from the door opening instead of that outer AABB.
		# Keep the socket well behind the closed-door plane. A shallow 30% inset
		# allowed wide/rotated loot to protrude through cabinet fronts.
		var world_position := opening_center.lerp(bounds.get_center(), 0.62)
		world_position.y = support_y
		var surface_points := _upward_surface_points(container)
		var nearest_surface_distance := INF
		if horizontal_lid:
			# This is a lift-up hatch, not a vertical cabinet front. Put loot on
			# the highest interior floor below the closed lid instead of on the lid.
			var lid_underside := opening_center.y - primary_box.size.y * 0.5
			var interior_surface_y := -INF
			for point: Dictionary in surface_points:
				var candidate_y: float = point.center.y
				if (
					candidate_y <= lid_underside - 0.04
					and candidate_y >= lid_underside - 0.40
					and candidate_y > interior_surface_y
				):
					interior_surface_y = candidate_y
			if not is_inf(interior_surface_y):
				support_y = interior_surface_y
			world_position.y = support_y
		for point: Dictionary in surface_points:
			var surface_center: Vector3 = point.center
			if (
				horizontal_lid
				and surface_center.y
					> opening_center.y - primary_box.size.y * 0.5 - 0.04
			):
				continue
			var distance := absf(surface_center.y - support_y)
			if distance <= 0.16 and distance < nearest_surface_distance:
				nearest_surface_distance = distance
				world_position.y = surface_center.y
		var size_limit := Vector3(
			maxf(0.16, bounds.size.x * 0.45),
			minf(0.42, bounds.size.y * 0.55),
			maxf(0.16, bounds.size.z * 0.45)
		)
		world_position.x = clampf(
			world_position.x,
			bounds.position.x + size_limit.x * 0.5,
			bounds.end.x - size_limit.x * 0.5
		)
		world_position.z = clampf(
			world_position.z,
			bounds.position.z + size_limit.z * 0.5,
			bounds.end.z - size_limit.z * 0.5
		)
		var socket := _add_world_loot_socket(
			world_position,
			type,
			size_limit,
			container
		) as LootSocket
		var inward_direction := bounds.get_center() - opening_center
		inward_direction.y = 0.0
		if not inward_direction.is_zero_approx():
			socket.set_meta(&"storage_inward_world", inward_direction.normalized())
		socket.set_meta(&"loot_capacity", 1)
		for door_node: Node in doors:
			socket.add_support(door_node)


func _setup_refrigerator_loot_sockets() -> void:
	var refrigerator := find_child("Refrigerador", true, false) as MeshInstance3D
	if refrigerator == null or refrigerator.mesh == null:
		return
	var refrigerator_bounds := _world_bounds(refrigerator)
	var surface_points := _merged_upward_surface_points(refrigerator)
	for child: Node in find_children("*", "HingedInteractable", true, false):
		var door := child as HingedInteractable
		if door.display_name not in ["freezer door", "refrigerator door"]:
			continue
		var box := door.moving_collision.shape as BoxShape3D
		if box == null:
			continue
		var door_center := door.to_global(door.moving_collision.position)
		var vertical_margin := minf(0.12, box.size.y * 0.22)
		var door_bottom := door_center.y - box.size.y * 0.5 + vertical_margin
		var door_top := door_center.y + box.size.y * 0.5 - vertical_margin
		var opening_direction := door_center - refrigerator_bounds.get_center()
		opening_direction.y = 0.0
		opening_direction = opening_direction.normalized()
		var created_count := 0
		for point: Dictionary in surface_points:
			var world_position := point.center as Vector3
			if world_position.y <= door_bottom or world_position.y >= door_top:
				continue
			# Bring loot toward the shelf opening while leaving enough depth around
			# every model. This keeps it visible and clear of the rear wall.
			world_position += opening_direction * 0.10
			var size_limit := Vector3(
				minf(0.58, refrigerator_bounds.size.x * 0.62),
				0.18 if door.display_name == "freezer door" else 0.28,
				minf(0.23, refrigerator_bounds.size.z * 0.36)
			)
			var placement_size := Vector3(
				minf(0.62, refrigerator_bounds.size.x * 0.68),
				size_limit.y,
				minf(0.18, refrigerator_bounds.size.z * 0.28)
			)
			var socket := _add_world_loot_socket(
				world_position,
				"fridge",
				size_limit,
				refrigerator,
				placement_size
			) as LootSocket
			socket.add_support(door)
			created_count += 1
		if created_count != (1 if door.display_name == "freezer door" else 3):
			push_warning("Unexpected %s shelf count: %d" % [
				door.display_name, created_count,
			])
		_thin_refrigerator_door_collision(door, refrigerator)


func _thin_refrigerator_door_collision(
	door: HingedInteractable,
	refrigerator: MeshInstance3D
) -> void:
	var collision := door.moving_collision
	var box := collision.shape as BoxShape3D
	if box == null:
		return
	var size := box.size
	var depth_axis := (
		Vector3.AXIS_X if size.x <= size.z else Vector3.AXIS_Z
	)
	var thickness := minf(0.07, size[depth_axis] * 0.35)
	var world_center := door.to_global(collision.position)
	var refrigerator_center := _world_bounds(refrigerator).get_center()
	var depth_direction := Vector3.RIGHT if depth_axis == Vector3.AXIS_X else Vector3.BACK
	var away_sign := signf((world_center - refrigerator_center).dot(depth_direction))
	if is_zero_approx(away_sign):
		away_sign = 1.0
	world_center[depth_axis] += away_sign * (size[depth_axis] - thickness) * 0.5
	size[depth_axis] = thickness
	box.size = size
	box.margin = 0.003
	collision.position = door.to_local(world_center)


func _setup_shelf_loot_sockets() -> void:
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var shelf := child as MeshInstance3D
		if shelf.mesh == null or not _matches_prefix(shelf.name, LOOT_SHELF_PREFIXES):
			continue
		var bounds := _world_bounds(shelf)
		var surface_points := _merged_upward_surface_points(shelf)
		var interior_points: Array[Dictionary] = []
		var top_margin := maxf(0.055, bounds.size.y * 0.025)
		for point: Dictionary in surface_points:
			if (
				bounds.size.y <= 1.4
				or (point.center as Vector3).y < bounds.end.y - top_margin
			):
				interior_points.append(point)
		while interior_points.size() > 6:
			interior_points.remove_at(0)
		if interior_points.is_empty():
			var fallback_count := clampi(roundi(bounds.size.y / 0.62), 1, 5)
			for level in fallback_count:
				var center := bounds.get_center()
				center.y = (
					bounds.position.y
					+ bounds.size.y * (float(level) + 0.22) / float(fallback_count)
				)
				interior_points.append({"center": center})
		var width_on_x := bounds.size.x >= bounds.size.z
		var width := bounds.size.x if width_on_x else bounds.size.z
		var column_count := clampi(roundi(width / 0.95), 1, 4)
		if String(shelf.name).begins_with("Librero") and width >= 3.0:
			column_count = 2
		for surface: Dictionary in interior_points:
			for column in column_count:
				var world_position := bounds.get_center()
				world_position.y = (surface.center as Vector3).y
				var lateral := width * (
					(float(column) + 0.5) / float(column_count) - 0.5
				) * (1.12 if column_count == 2 and width >= 3.0 else 0.76)
				if width_on_x:
					world_position.x += lateral
				else:
					world_position.z += lateral
				var size_limit := Vector3(
					minf(0.38, bounds.size.x * 0.62 / float(column_count)),
					minf(0.36, bounds.size.y * 0.42 / float(interior_points.size())),
					minf(0.38, bounds.size.z * 0.62 / float(column_count))
				)
				var placement_size := size_limit
				var lateral_span := width * 0.76 / float(column_count)
				if width_on_x:
					placement_size.x = maxf(size_limit.x, lateral_span)
					placement_size.z = maxf(size_limit.z, bounds.size.z * 0.62)
				else:
					placement_size.x = maxf(size_limit.x, bounds.size.x * 0.62)
					placement_size.z = maxf(size_limit.z, lateral_span)
				_add_world_loot_socket(
					world_position,
					"shelf",
					size_limit,
					shelf,
					placement_size
				)


func _setup_table_loot_sockets() -> void:
	var tables := find_child("Mesas", true, false)
	if tables == null:
		return
	for child: Node in tables.get_children():
		var table := child as MeshInstance3D
		if table == null or table.mesh == null or not String(table.name).begins_with("Mesa"):
			continue
		var bounds := _world_bounds(table)
		var world_position := bounds.get_center()
		var surface_levels := _upward_surface_levels(table)
		world_position.y = (
			bounds.end.y
			if surface_levels.is_empty()
			else surface_levels.back()
		)
		var size_limit := Vector3(
			minf(0.48, bounds.size.x * 0.55),
			0.45,
			minf(0.48, bounds.size.z * 0.55)
		)
		var placement_size := Vector3(
			maxf(size_limit.x, bounds.size.x * 0.70),
			size_limit.y,
			maxf(size_limit.z, bounds.size.z * 0.70)
		)
		_add_world_loot_socket(
			world_position,
			"table",
			size_limit,
			table,
			placement_size
		)


func _upward_surface_levels(mesh_instance: MeshInstance3D) -> Array[float]:
	var surface_points := _merged_upward_surface_points(mesh_instance)
	var result: Array[float] = []
	for point: Dictionary in surface_points:
		result.append((point.center as Vector3).y)
	while result.size() > 6:
		result.remove_at(0)
	return result


func _merged_upward_surface_points(mesh_instance: MeshInstance3D) -> Array[Dictionary]:
	var surface_points := _upward_surface_points(mesh_instance)
	if surface_points.is_empty():
		return surface_points
	var largest_area := 0.0
	for point: Dictionary in surface_points:
		largest_area = maxf(largest_area, float(point.area))
	var merged: Array[Dictionary] = []
	for point: Dictionary in surface_points:
		if float(point.area) < largest_area * 0.18:
			continue
		if (
			not merged.is_empty()
			and (point.center as Vector3).y - (merged.back().center as Vector3).y <= 0.075
		):
			# Two close levels are the bottom/top faces of one shelf board.
			# The higher face is the support surface.
			merged[-1] = point
		else:
			merged.append(point)
	return merged


func _upward_surface_points(mesh_instance: MeshInstance3D) -> Array[Dictionary]:
	var level_data := {}
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in triangle_count:
			var vertex_indices := PackedInt32Array([
				indices[triangle_index * 3] if not indices.is_empty() else triangle_index * 3,
				indices[triangle_index * 3 + 1] if not indices.is_empty() else triangle_index * 3 + 1,
				indices[triangle_index * 3 + 2] if not indices.is_empty() else triangle_index * 3 + 2,
			])
			var a := mesh_instance.global_transform * vertices[vertex_indices[0]]
			var b := mesh_instance.global_transform * vertices[vertex_indices[1]]
			var c := mesh_instance.global_transform * vertices[vertex_indices[2]]
			var cross := (b - a).cross(c - a)
			var area := cross.length() * 0.5
			if area < 0.0004 or absf(cross.normalized().y) < 0.72:
				continue
			var centroid := (a + b + c) / 3.0
			var level_key := roundi(centroid.y * 40.0)
			if not level_data.has(level_key):
				level_data[level_key] = {
					"area": 0.0,
					"weighted_center": Vector3.ZERO,
				}
			level_data[level_key].area += area
			level_data[level_key].weighted_center += centroid * area

	var result: Array[Dictionary] = []
	for level_key: int in level_data:
		var data: Dictionary = level_data[level_key]
		result.append({
			"area": data.area,
			"center": data.weighted_center / data.area,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.center as Vector3).y < (b.center as Vector3).y
	)
	return result


func _nearest_storage_container(
	world_position: Vector3,
	containers: Array[MeshInstance3D]
) -> MeshInstance3D:
	var nearest: MeshInstance3D
	var nearest_distance := INF
	for container in containers:
		var bounds := _world_bounds(container).grow(0.12)
		var closest := Vector3(
			clampf(world_position.x, bounds.position.x, bounds.end.x),
			clampf(world_position.y, bounds.position.y, bounds.end.y),
			clampf(world_position.z, bounds.position.z, bounds.end.z)
		)
		var distance := closest.distance_to(world_position)
		if distance < nearest_distance:
			nearest = container
			nearest_distance = distance
	# Some imported door meshes sit nearly a meter outside their parent mesh AABB
	# (the panel was authored separately). The nearest eligible furniture remains
	# unambiguous at this radius.
	return nearest if nearest_distance <= 1.15 else null


func _add_world_loot_socket(
	world_position: Vector3,
	type: String,
	size_limit: Vector3,
	source: Node,
	placement_size: Vector3 = Vector3.ZERO
) -> Marker3D:
	return _add_loot_socket(
		self,
		to_local(world_position),
		type,
		size_limit,
		source,
		placement_size
	)


func _add_loot_socket(
	parent: Node3D,
	local_position: Vector3,
	type: String,
	size_limit: Vector3,
	source: Node,
	placement_size: Vector3 = Vector3.ZERO
) -> Marker3D:
	var socket := LOOT_SOCKET_SCRIPT.new() as Marker3D
	socket.name = "LootSocket_%s" % type.capitalize().replace(" ", "")
	parent.add_child(socket)
	socket.position = local_position
	socket.configure(type, size_limit, source, placement_size)
	return socket


func _setup_laundry_lids() -> void:
	for mesh in _find_meshes(&"Lavanderia", "Tapa"):
		var bounds := _world_bounds(mesh)
		if bounds.size.y < 0.1:
			_wrap_horizontal_hinge(mesh, "washer lid", 75.0)
		else:
			_wrap_vertical_hinge(mesh, "dryer door", 105.0)


func _setup_interactable_televisions() -> void:
	for mesh_name: StringName in TELEVISION_MESH_NAMES:
		var television_mesh := find_child(mesh_name, true, false) as MeshInstance3D
		if television_mesh == null or television_mesh.mesh == null:
			continue
		var screen_surface := _find_television_atlas_surface(television_mesh)
		if screen_surface < 0:
			push_warning("No TV atlas material found on %s" % television_mesh.name)
			continue
		var source_material := (
			television_mesh.get_active_material(screen_surface) as StandardMaterial3D
		)
		if source_material == null or source_material.albedo_texture == null:
			continue

		var bounds := _world_bounds(television_mesh)
		var body := TelevisionInteractable.new()
		body.name = "Television_%s" % television_mesh.name
		add_child(body)
		body.global_transform = Transform3D(Basis.IDENTITY, television_mesh.global_position)
		television_mesh.reparent(body, true)
		body.configure_collision(bounds)

		var screen_material := ShaderMaterial.new()
		screen_material.shader = TELEVISION_SCREEN_SHADER
		screen_material.set_shader_parameter("base_texture", source_material.albedo_texture)
		screen_material.set_shader_parameter(
			"screen_mask_texture",
			TELEVISION_SCREEN_MASKS.get(mesh_name)
		)
		screen_material.set_shader_parameter(
			"screen_rect",
			TELEVISION_SCREEN_RECTS.get(mesh_name, Vector4(0.02, 0.05, 0.75, 0.87))
		)
		television_mesh.set_surface_override_material(screen_surface, screen_material)
		body.screen_material = screen_material
		_configure_television_light(
			body,
			bounds,
			TELEVISION_FRONT_NORMALS.get(mesh_name, Vector3.FORWARD)
		)
		body.set_on_immediate(false)


func _find_television_atlas_surface(television: MeshInstance3D) -> int:
	for surface_index in television.mesh.get_surface_count():
		var material := television.get_active_material(surface_index)
		if material != null and material.resource_name in [&"Tele1", &"Tele2"]:
			return surface_index
	return -1


func _configure_television_light(
	body: TelevisionInteractable,
	bounds: AABB,
	front_normal: Vector3
) -> void:
	var front := front_normal.normalized()
	var light := SpotLight3D.new()
	light.name = "ScreenLight"
	light.light_color = Color(0.38, 0.58, 0.72)
	light.light_energy = body.screen_light_energy
	light.spot_range = 2.8
	light.spot_angle = 58.0
	light.spot_attenuation = 1.8
	light.shadow_enabled = false
	body.add_child(light)
	light.global_position = bounds.get_center() + front * 0.06
	light.global_basis = Basis.looking_at(front, Vector3.UP)
	body.screen_light = light


func _setup_interactable_lights() -> void:
	var lamp_meshes: Array[MeshInstance3D] = []
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var lamp_mesh := child as MeshInstance3D
		if lamp_mesh.mesh != null and _matches_prefix(lamp_mesh.name, LAMP_PREFIXES):
			lamp_meshes.append(lamp_mesh)

	for lamp_mesh in lamp_meshes:
		var world_bounds := _world_bounds(lamp_mesh)
		var bulb_position := _find_bulb_position(lamp_mesh)
		var body := LightInteractable.new()
		body.name = "Light_%s" % lamp_mesh.name
		body.display_name = "lamp"
		add_child(body)
		body.global_transform = Transform3D(Basis.IDENTITY, lamp_mesh.global_position)
		lamp_mesh.reparent(body, true)
		body.configure_collision(world_bounds)

		for surface_index in lamp_mesh.mesh.get_surface_count():
			var material := lamp_mesh.get_active_material(surface_index) as StandardMaterial3D
			if material == null or material.resource_name not in LAMP_MATERIALS:
				continue
			var unique_material := material.duplicate() as StandardMaterial3D
			unique_material.emission_enabled = true
			unique_material.emission_energy_multiplier = 2.2
			lamp_mesh.set_surface_override_material(surface_index, unique_material)
			body.add_emissive_material(unique_material)

		var light := OmniLight3D.new()
		light.name = "%sGlow" % lamp_mesh.name
		light.light_color = Color(1.0, 0.61, 0.25)
		light.light_energy = 0.5
		light.omni_range = 3.0
		light.omni_attenuation = 1.45
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 10.0
		light.distance_fade_length = 5.0
		body.add_child(light)
		light.global_position = bulb_position
		body.controlled_light = light


func _wrap_vertical_hinge(
	mesh: MeshInstance3D,
	label: String,
	open_angle: float
) -> HingedInteractable:
	var body := HingedInteractable.new()
	body.name = "Hinged_%s" % mesh.name
	body.display_name = label
	body.open_angle_degrees = open_angle
	body.movement_speed = 1.8
	var bounds := _world_bounds(mesh)
	add_child(body)
	body.global_transform = Transform3D(Basis.IDENTITY, mesh.global_position)
	mesh.reparent(body, true)
	body.configure_bounds_collision(bounds)
	return body


func _wrap_horizontal_hinge(
	mesh: MeshInstance3D,
	label: String,
	open_angle: float
) -> HingedInteractable:
	var bounds := _world_bounds(mesh)
	var mesh_origin := mesh.global_position
	var body := _wrap_vertical_hinge(mesh, label, open_angle)
	var x_edge_distance := minf(
		absf(mesh_origin.x - bounds.position.x),
		absf(bounds.end.x - mesh_origin.x)
	) / maxf(bounds.size.x, 0.001)
	var z_edge_distance := minf(
		absf(mesh_origin.z - bounds.position.z),
		absf(bounds.end.z - mesh_origin.z)
	) / maxf(bounds.size.z, 0.001)
	body.hinge_axis = Vector3.FORWARD if x_edge_distance < z_edge_distance else Vector3.RIGHT
	body.choose_direction_from_actor = false
	body.open_direction = (
		1.0
		if body._open_center_for_direction(1.0).y >= body._open_center_for_direction(-1.0).y
		else -1.0
	)
	return body


func _wrap_slider(
	mesh: MeshInstance3D,
	label: String,
	world_axis: Vector3,
	travel: float,
	toward_actor: bool,
	direction: float
) -> SlidingInteractable:
	var body := SlidingInteractable.new()
	body.name = "Sliding_%s" % mesh.name
	body.display_name = label
	body.travel_distance = travel
	body.choose_direction_toward_actor = toward_actor
	body.open_direction = direction
	body.movement_speed = 2.8
	var bounds := _world_bounds(mesh)
	add_child(body)
	body.global_transform = Transform3D(Basis.IDENTITY, mesh.global_position)
	body.configure_slide_axis(world_axis)
	mesh.reparent(body, true)
	body.configure_bounds_collision(bounds)
	return body


func _find_meshes(parent_name: StringName, prefix: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or mesh.get_parent().name != parent_name:
			continue
		if not prefix.is_empty() and not String(mesh.name).begins_with(prefix):
			continue
		result.append(mesh)
	return result


func _world_bounds(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.get_aabb()


func _configure_imported_drawer(
	drawer: SlidingInteractable,
	drawer_bounds: AABB,
	container: MeshInstance3D,
	force_closed: bool
) -> void:
	if container == null:
		return
	var cabinet_center := _world_bounds(container).get_center()
	var drawer_center := drawer_bounds.get_center()
	var source_offset := (drawer_center - cabinet_center).dot(drawer.slide_axis_world)
	if is_zero_approx(source_offset):
		source_offset = 0.01
	var outward_direction := signf(source_offset)
	var source_extension := absf(source_offset)
	var drawer_depth := (
		absf(drawer.slide_axis_world.x) * drawer_bounds.size.x
		+ absf(drawer.slide_axis_world.z) * drawer_bounds.size.z
	)
	# Expose most of the cavity. A half-depth opening leaves rear loot visually
	# and physically trapped under the cabinet even though the drawer is "open".
	var safe_open_distance := clampf(drawer_depth * 0.85, 0.28, 0.72)
	drawer.open_direction = outward_direction
	drawer.travel_distance = maxf(safe_open_distance, source_extension)
	drawer.configure_open_top_collision(drawer_bounds)
	drawer.closed_transform.origin -= (
		drawer.slide_axis_parent * outward_direction * source_extension
	)
	var initial_progress := clampf(source_extension / drawer.travel_distance, 0.0, 1.0)
	if force_closed:
		initial_progress = 0.0
	drawer.movement_progress = initial_progress
	drawer.target_progress = initial_progress
	drawer.is_open = initial_progress >= 0.8
	drawer.transform = drawer._transform_for_progress(initial_progress)


func _horizontal_depth_axis(mesh: MeshInstance3D) -> Vector3:
	if mesh == null or mesh.mesh == null:
		return Vector3.ZERO
	var local_size := mesh.get_aabb().size
	var best_axis := Vector3.ZERO
	var best_extent := INF
	for axis_index in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		var world_axis := mesh.global_transform.basis[axis_index]
		var axis_length := world_axis.length()
		if axis_length <= 0.0001:
			continue
		var direction := world_axis / axis_length
		if absf(direction.y) > 0.25:
			continue
		var extent := local_size[axis_index] * axis_length
		if extent < best_extent:
			best_extent = extent
			best_axis = direction
	return best_axis.normalized()


func _has_interactable_ancestor(node: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor.is_in_group("interactable"):
			return true
		ancestor = ancestor.get_parent()
	return false


func _find_bulb_position(lamp_mesh: MeshInstance3D) -> Vector3:
	var bounds := lamp_mesh.mesh.get_aabb()
	var local_bulb := bounds.get_center()
	var bounds_end := bounds.position + bounds.size
	var strongest_axis := 0
	var strongest_bias := 0.0

	# Imported sconces use their wall mount as the origin. The bulb sits near
	# the far end of the most asymmetric mesh axis, inside the lampshade.
	for axis in 3:
		var axis_bias: float = abs(abs(bounds_end[axis]) - abs(bounds.position[axis]))
		if axis_bias > strongest_bias:
			strongest_bias = axis_bias
			strongest_axis = axis

	if strongest_bias > bounds.size[strongest_axis] * 0.2:
		var far_end: float = bounds_end[strongest_axis]
		if abs(bounds.position[strongest_axis]) > abs(far_end):
			far_end = bounds.position[strongest_axis]
		local_bulb[strongest_axis] = far_end * 0.8

	return lamp_mesh.to_global(local_bulb)


func _fix_imported_glass() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.055, 0.075, 0.095, 0.58)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.18
	glass.metallic_specular = 0.45
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			if material != null and material.resource_name == "Vidrio.001":
				mesh_instance.set_surface_override_material(surface_index, glass)


func _fix_invalid_imported_materials() -> void:
	var repaired: Dictionary = {}
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null or repaired.has(material.get_instance_id()):
				continue
			repaired[material.get_instance_id()] = true
			if material.resource_name == "White" and material.albedo_texture == null:
				material.albedo_color = Color(0.72, 0.72, 0.68)
				material.roughness = 0.85
				continue


func _fix_imported_carpet_materials() -> void:
	var repaired: Dictionary = {}
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null or not material.resource_name.begins_with("Carpet_"):
				continue

			var source_id := material.get_instance_id()
			var carpet_material: StandardMaterial3D
			if repaired.has(source_id):
				carpet_material = repaired[source_id]
			else:
				carpet_material = material.duplicate() as StandardMaterial3D
				# The FBX enables albedo vertex-color modulation on rug meshes that
				# contain no color channel, so their textures render black.
				carpet_material.vertex_color_use_as_albedo = false
				carpet_material.emission_enabled = false
				carpet_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				carpet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				carpet_material.alpha_scissor_threshold = 0.2
				carpet_material.roughness = 0.9
				repaired[source_id] = carpet_material
			mesh_instance.set_surface_override_material(surface_index, carpet_material)

func _needs_structure_collision(node_name: StringName) -> bool:
	var text := String(node_name)
	if text in COLLISION_EXACT_NAMES:
		return true
	return _matches_prefix(node_name, STRUCTURE_COLLISION_PREFIXES)


func _footstep_surface_for_mesh(mesh_instance: MeshInstance3D) -> StringName:
	var material_names := ""
	for surface_index in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface_index)
		if material != null:
			material_names += " " + material.resource_name.to_lower()
	var mesh_name := String(mesh_instance.name).to_lower()
	var surface_hint := mesh_name + material_names
	if "carpet" in surface_hint or "alfombra" in surface_hint or "alfonbra" in surface_hint:
		return &"carpet"
	if "metal" in surface_hint:
		return &"metal"
	if "madera" in surface_hint or "wood" in surface_hint:
		return &"wood"
	if "pasto" in surface_hint or "grass" in surface_hint:
		return &"grass"
	if "piso2" in surface_hint or "piso_cocina" in surface_hint or "piso_piscina" in surface_hint:
		return &"tile"
	return &"concrete"


func _setup_footstep_area(mesh_instance: MeshInstance3D, surface: StringName) -> void:
	var shape := mesh_instance.mesh.create_trimesh_shape()
	if shape == null:
		return
	var area := Area3D.new()
	area.name = "%sFootstepArea" % mesh_instance.name
	area.collision_layer = FOOTSTEP_AREA_LAYER
	area.collision_mask = 0
	area.set_meta(&"footstep_surface", surface)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	mesh_instance.add_child(area)
	area.add_child(collision)


func _matches_prefix(node_name: StringName, prefixes: Array) -> bool:
	var text := String(node_name)
	for prefix: String in prefixes:
		if text.begins_with(prefix):
			return true
	return false
