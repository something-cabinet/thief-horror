extends Node3D

const TELEVISION_SCREEN_SHADER := preload("res://material/television_screen.gdshader")

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


func _ready() -> void:
	_fix_invalid_imported_materials()
	_fix_imported_carpet_materials()
	_fix_imported_glass()
	_setup_front_door()
	_setup_refrigerator_doors()
	_setup_van_doors()
	_setup_cabinet_parts()
	_setup_laundry_lids()
	_setup_interactable_televisions()
	_setup_interactable_lights()
	var structure_count := 0
	var prop_count := 0
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or _has_interactable_ancestor(mesh_instance):
			continue

		var is_solid_prop := (
			mesh_instance.name == &"Ban"
			or mesh_instance.name in STATIC_CABINET_PARTS
			or _matches_prefix(mesh_instance.name, SOLID_PROP_PREFIXES)
		)
		var is_structure := _needs_structure_collision(mesh_instance.name)
		var uses_exact_prop_collision := (
			mesh_instance.name in [&"Ban", &"Cofre"]
			or _matches_prefix(mesh_instance.name, EXACT_PROP_COLLISION_PREFIXES)
		)
		if not is_solid_prop and not is_structure:
			continue

		var body := StaticBody3D.new()
		body.name = "%sCollision" % mesh_instance.name
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
		var door_bounds := _world_bounds(mesh)
		var body := _wrap_vertical_hinge(mesh, label, 95.0)
		var normal_axis := (
			Vector3.RIGHT if door_bounds.size.x <= door_bounds.size.z else Vector3.FORWARD
		)
		if (door_bounds.get_center() - van_center).dot(normal_axis) < 0.0:
			normal_axis = -normal_axis
		body.restrict_interaction_to_side(normal_axis)


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
	var safe_open_distance := clampf(drawer_depth * 0.55, 0.22, 0.48)
	drawer.open_direction = outward_direction
	drawer.travel_distance = maxf(safe_open_distance, source_extension)
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


func _matches_prefix(node_name: StringName, prefixes: Array) -> bool:
	var text := String(node_name)
	for prefix: String in prefixes:
		if text.begins_with(prefix):
			return true
	return false
