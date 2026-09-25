extends Node3D

const FIELD_CENTER := Vector3(-40.0, 13.0, -127.5)
const FIELD_EXTENTS := Vector3(34.0, 0.5, 34.0)
const DROP_RADIUS := 0.0055
const DROP_LENGTH := 0.34

var roof_collision: GPUParticlesCollisionHeightField3D
var world_rain: GPUParticles3D


func _enter_tree() -> void:
	print("[RAIN_DEBUG] enter_tree path=%s parent=%s" % [get_path(), get_parent().get_path()])


func _ready() -> void:
	print("[RAIN_DEBUG] ready path=%s process_mode=%d world=%d" % [
		get_path(),
		process_mode,
		get_world_3d().get_instance_id(),
	])
	_create_static_roof_collision()
	# The map and height-field collision must be registered with RenderingServer
	# before the particle simulation starts.
	await get_tree().process_frame
	_create_world_rain()
	debug_status("ready_complete")
	get_tree().create_timer(1.0).timeout.connect(debug_status.bind("one_second"), CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	print("[RAIN_DEBUG] exit_tree path=%s" % get_path())


func _create_static_roof_collision() -> void:
	roof_collision = GPUParticlesCollisionHeightField3D.new()
	roof_collision.name = "RoofCollision"
	roof_collision.position = Vector3(FIELD_CENTER.x, 5.0, FIELD_CENTER.z)
	roof_collision.size = Vector3(FIELD_EXTENTS.x * 2.0, 24.0, FIELD_EXTENTS.z * 2.0)
	roof_collision.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_2048
	roof_collision.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(roof_collision)


func _create_world_rain() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# A single velocity-aligned 3D drop gives a continuous projection:
	# streak from the side, round cross-section from above, and every angle between.
	var drop_mesh := CylinderMesh.new()
	drop_mesh.material = material
	drop_mesh.top_radius = DROP_RADIUS
	drop_mesh.bottom_radius = DROP_RADIUS
	drop_mesh.height = DROP_LENGTH
	drop_mesh.radial_segments = 8
	drop_mesh.rings = 1
	drop_mesh.cap_top = true
	drop_mesh.cap_bottom = true

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = FIELD_EXTENTS
	process.direction = Vector3(0.04, -1.0, 0.018)
	process.spread = 2.5
	process.particle_flag_align_y = true
	process.gravity = Vector3(0.45, -2.5, 0.18)
	process.initial_velocity_min = 9.0
	process.initial_velocity_max = 13.0
	process.scale_min = 0.45
	process.scale_max = 0.95
	process.color = Color(0.62, 0.72, 0.86, 0.58)
	process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT

	world_rain = GPUParticles3D.new()
	world_rain.name = "WorldRain"
	world_rain.position = FIELD_CENTER
	world_rain.amount = 3200
	world_rain.lifetime = 1.25
	world_rain.preprocess = 1.25
	world_rain.randomness = 0.3
	world_rain.fixed_fps = 120
	world_rain.fract_delta = true
	world_rain.local_coords = false
	world_rain.visibility_aabb = AABB(
		Vector3(-FIELD_EXTENTS.x, -28.0, -FIELD_EXTENTS.z),
		Vector3(FIELD_EXTENTS.x * 2.0, 34.0, FIELD_EXTENTS.z * 2.0)
	)
	world_rain.process_material = process
	world_rain.draw_passes = 1
	world_rain.draw_pass_1 = drop_mesh
	add_child(world_rain)


func debug_status(stage: String) -> void:
	var world_id := get_world_3d().get_instance_id() if is_inside_tree() else 0
	var rain_valid := is_instance_valid(world_rain)
	print("[RAIN_DEBUG] status=%s inside_tree=%s visible_tree=%s process_mode=%d world=%d rain_valid=%s" % [
		stage,
		is_inside_tree(),
		is_visible_in_tree() if is_inside_tree() else false,
		process_mode,
		world_id,
		rain_valid,
	])
	if rain_valid:
		print("[RAIN_DEBUG] emitter path=%s emitting=%s amount=%d visible=%s visible_tree=%s position=%s aabb=%s" % [
			world_rain.get_path(),
			world_rain.emitting,
			world_rain.amount,
			world_rain.visible,
			world_rain.is_visible_in_tree(),
			world_rain.global_position,
			world_rain.visibility_aabb,
		])
