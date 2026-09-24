extends Node3D

const MAP_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const PLAYER_SCENE := preload("res://entity/player/Player.tscn")
const LEVEL_SCENE := preload("res://level/Level1.tscn")
const DT := 1.0 / 60.0
const WALK_SPEED := 4.0

var player: Player
var failures: Array[String] = []


func _ready() -> void:
	_verify_level_spawn()
	var map := MAP_SCENE.instantiate()
	add_child(map)
	_verify_trimesh_collision(map, "Pizarra")
	_verify_trimesh_collision(map, "Poste_Luz")
	_verify_trimesh_collision_prefix(map, "Mesa")

	player = PLAYER_SCENE.instantiate() as Player
	player.collision_layer = 4
	player.collision_mask = 1
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_add_synthetic_course()
	await get_tree().physics_frame

	await _test_path(
		"basement stairs center",
		Vector3(-30.344, -2.775, -126.806),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(position: Vector3) -> bool: return position.x < -35.0 and position.y > 0.75
	)
	await _test_path(
		"basement stairs left edge",
		Vector3(-30.344, -2.775, -126.25),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(position: Vector3) -> bool: return position.x < -35.0 and position.y > 0.75
	)
	await _test_path(
		"basement stairs right edge",
		Vector3(-30.344, -2.775, -126.92),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(position: Vector3) -> bool: return position.x < -35.0 and position.y > 0.75
	)
	await _test_path(
		"upper stairs center",
		Vector3(-29.554, 0.811, -126.568),
		Vector3(-1.0, 0.0, 0.0),
		120,
		func(position: Vector3) -> bool: return position.x < -35.0 and position.y > 4.2
	)
	await _test_path(
		"upper stairs right edge",
		Vector3(-29.554, 0.811, -127.093),
		Vector3(-1.0, 0.0, 0.0),
		120,
		func(position: Vector3) -> bool: return position.x < -35.0 and position.y > 4.2
	)
	await _test_path(
		"upper stairs descend",
		Vector3(-34.2, 4.378, -126.568),
		Vector3(1.0, 0.0, 0.0),
		120,
		func(position: Vector3) -> bool: return position.x > -30.0 and position.y < 1.3
	)
	await _test_path(
		"basement stairs descend",
		Vector3(-34.2, 0.81, -126.568),
		Vector3(1.0, 0.0, 0.0),
		120,
		func(position: Vector3) -> bool: return position.x > -30.0 and position.y < -2.3
	)
	await _test_path(
		"front doorstep",
		Vector3(-29.0, 0.811, -114.5),
		Vector3(0.0, 0.0, -1.0),
		90,
		func(position: Vector3) -> bool: return position.z < -116.0
	)
	await _test_path(
		"front doorway right enter",
		Vector3(-28.28, 0.811, -114.5),
		Vector3(0.0, 0.0, -1.0),
		90,
		func(position: Vector3) -> bool: return position.z < -117.0
	)
	await _test_path(
		"front doorway right exit",
		Vector3(-28.28, 0.811, -118.069),
		Vector3(0.0, 0.0, 1.0),
		90,
		func(position: Vector3) -> bool: return position.z > -115.0
	)
	await _test_path(
		"synthetic 0.25m step",
		Vector3(99.0, 1.001, 100.0),
		Vector3(1.0, 0.0, 0.0),
		40,
		func(position: Vector3) -> bool: return position.x > 101.5 and position.y > 1.18
	)
	await _test_path(
		"synthetic narrow doorway",
		Vector3(99.0, 1.001, 108.0),
		Vector3(1.0, 0.0, 0.0),
		75,
		func(position: Vector3) -> bool: return position.x > 102.0
	)
	await _test_path(
		"synthetic 0.50m obstacle stays blocked",
		Vector3(99.0, 1.001, 104.0),
		Vector3(1.0, 0.0, 0.0),
		60,
		func(position: Vector3) -> bool: return position.x < 99.8 and position.y < 1.1
	)

	if failures.is_empty():
		print("[STEP_TEST] PASS all movement cases")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[STEP_TEST] %s" % failure)
		get_tree().quit(1)


func _verify_level_spawn() -> void:
	var level := LEVEL_SCENE.instantiate()
	var spawn := level.get_node("Player") as Player
	var expected_position := Vector3(-51.526, -0.187, -104.284)
	if not spawn.position.is_equal_approx(expected_position):
		failures.append("level spawn position is %s" % spawn.position)
	if not is_equal_approx(spawn.rotation_degrees.y, -40.6):
		failures.append("level spawn yaw is %.1f" % spawn.rotation_degrees.y)
	if not is_equal_approx(spawn.initial_camera_pitch_degrees, 1.3):
		failures.append("level spawn pitch is %.1f" % spawn.initial_camera_pitch_degrees)
	print("[SPAWN_TEST] xyz=%s yaw=%.1f pitch=%.1f" % [
		spawn.position,
		spawn.rotation_degrees.y,
		spawn.initial_camera_pitch_degrees,
	])
	level.free()


func _verify_trimesh_collision(map: Node, mesh_name: String) -> void:
	var mesh := map.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh == null:
		failures.append("%s mesh is missing" % mesh_name)
		return
	var body := mesh.find_child("%sCollision" % mesh_name, false, false) as StaticBody3D
	if body == null:
		failures.append("%s collision body is missing" % mesh_name)
		return
	var collision := body.find_child("*", false, false) as CollisionShape3D
	if collision == null or not collision.shape is ConcavePolygonShape3D:
		failures.append("%s does not have exact trimesh collision" % mesh_name)
		return
	print("[COLLISION_TEST] %s exact trimesh collision ready" % mesh_name)


func _verify_trimesh_collision_prefix(map: Node, prefix: String) -> void:
	var matched := 0
	for child: Node in map.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or not mesh.name.begins_with(prefix):
			continue
		matched += 1
		var body := mesh.find_child("%sCollision" % mesh.name, false, false) as StaticBody3D
		var collision: CollisionShape3D = null
		if body != null:
			collision = body.find_child("*", false, false) as CollisionShape3D
		if collision == null or not collision.shape is ConcavePolygonShape3D:
			failures.append("%s does not have exact trimesh collision" % mesh.name)
	if matched == 0:
		failures.append("no %s meshes found" % prefix)
	else:
		print("[COLLISION_TEST] %d %s meshes use exact trimesh collision" % [matched, prefix])


func _test_path(
	name: String,
	start: Vector3,
	direction: Vector3,
	frames: int,
	passed: Callable
) -> void:
	player.global_position = start
	player.velocity = Vector3.DOWN
	player.vel_vertical = -1.0
	player.jumped = false
	player.is_step_traversing = false
	player.neck.position.y = 0.0
	player.move_and_slide()
	await get_tree().physics_frame

	var step_count := 0
	var longest_stall := 0
	var current_stall := 0
	var vertical_speed := -0.1
	var max_camera_rise := 0.0
	for frame in frames:
		var before_move := player.global_position
		var before_camera_y := player.player_camera.global_position.y
		if player.is_on_floor():
			vertical_speed = -0.1
		else:
			vertical_speed = maxf(vertical_speed - 14.0 * DT, -50.0)
		player.velocity = direction * WALK_SPEED + Vector3.UP * vertical_speed
		var stepped := player._try_step_up(direction * WALK_SPEED * DT)
		if stepped:
			step_count += 1
			vertical_speed = 0.0
		else:
			player.move_and_slide()
		player.camera_control(DT)
		max_camera_rise = maxf(
			max_camera_rise,
			player.player_camera.global_position.y - before_camera_y
		)

		await get_tree().physics_frame
		var horizontal_delta := player.global_position - before_move
		horizontal_delta.y = 0.0
		if horizontal_delta.length() < 0.0001:
			current_stall += 1
			longest_stall = maxi(longest_stall, current_stall)
		else:
			current_stall = 0

	var result := passed.call(player.global_position) as bool
	if max_camera_rise > 0.1:
		result = false
	print("[STEP_TEST] %s result=%s xyz=%s steps=%d max_stall=%d camera_rise=%.3f last=%s" % [
		name,
		result,
		player.global_position,
		step_count,
		longest_stall,
		max_camera_rise,
		player.step_debug_reason,
	])
	if not result:
		failures.append("%s failed at %s (%s)" % [name, player.global_position, player.step_debug_reason])
func _add_synthetic_course() -> void:
	_add_box("SyntheticFloor", Vector3(102.0, -0.1, 104.0), Vector3(10.0, 0.2, 14.0))
	_add_box("ShortStep", Vector3(101.0, 0.125, 100.0), Vector3(2.0, 0.25, 2.5))
	_add_box("TallObstacle", Vector3(101.0, 0.25, 104.0), Vector3(2.0, 0.5, 2.5))
	_add_box("DoorwayLeft", Vector3(101.5, 1.5, 107.59), Vector3(3.0, 3.0, 0.2))
	_add_box("DoorwayRight", Vector3(101.5, 1.5, 108.41), Vector3(3.0, 3.0, 0.2))


func _add_box(name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = position
	body.add_child(collision)
	add_child(body)
