extends Node3D

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
	_add_lamp_lighting()
	var structure_count := 0
	var prop_count := 0
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var is_solid_prop := mesh_instance.name == &"Ban" or _matches_prefix(mesh_instance.name, SOLID_PROP_PREFIXES)
		var is_structure := _needs_structure_collision(mesh_instance.name)
		var uses_exact_prop_collision := _matches_prefix(mesh_instance.name, EXACT_PROP_COLLISION_PREFIXES)
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


func _add_lamp_lighting() -> void:
	var brightened_materials: Dictionary = {}
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var lamp_mesh := child as MeshInstance3D
		if lamp_mesh.mesh == null or not _matches_prefix(lamp_mesh.name, LAMP_PREFIXES):
			continue

		for surface_index in lamp_mesh.mesh.get_surface_count():
			var material := lamp_mesh.get_active_material(surface_index) as StandardMaterial3D
			if material == null or material.resource_name not in LAMP_MATERIALS:
				continue
			if not brightened_materials.has(material.get_instance_id()):
				brightened_materials[material.get_instance_id()] = true
				material.emission_enabled = true
				material.emission_energy_multiplier = 2.2

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
		add_child(light)
		light.global_position = _find_bulb_position(lamp_mesh)


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
