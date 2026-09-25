extends Node3D

# Automated regression test (not used by the game). Run _step_solver_test.tscn directly,
# or headless: godot --headless res://level/_step_solver_test.tscn
# Checks:
#   - Level1 player spawn position/yaw/pitch.
#   - Collision setup on specific map meshes (trimesh vs. box, non-interactive props).
#   - Interactables: expected counts, open/close animation, outlines, lamps, TVs,
#     drawer start states, van doors only usable from outside, front door.
#   - Player movement: walks a physics-driven player through stairs, doorways and a
#     synthetic step/obstacle course, checking step-up works, tall obstacles block,
#     and the camera doesn't jerk upward.
# Prints [..._TEST] lines; quits with exit code 0 if everything passes, 1 on any failure.
# NOTE: expected counts and coordinates are hard-coded, so update them when the map changes.

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
	_verify_trimesh_collision(map, "Ban")
	_verify_static_box_collision(map, "p_024")
	_verify_static_box_collision(map, "p_041")
	_verify_trimesh_collision_prefix(map, "Mesa")
	_verify_interactables(map)
	_verify_front_door(map)

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
	_verify_airborne_wedge_recovery()

	await _test_path(
		"basement stairs center",
		Vector3(-30.344, -2.775, -126.806),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(pos: Vector3) -> bool: return pos.x < -35.0 and pos.y > 0.75
	)
	await _test_path(
		"basement stairs left edge",
		Vector3(-30.344, -2.775, -126.25),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(pos: Vector3) -> bool: return pos.x < -35.0 and pos.y > 0.75
	)
	await _test_path(
		"basement stairs right edge",
		Vector3(-30.344, -2.775, -126.92),
		Vector3(-1.0, 0.0, 0.0),
		130,
		func(pos: Vector3) -> bool: return pos.x < -35.0 and pos.y > 0.75
	)
	await _test_path(
		"upper stairs center",
		Vector3(-29.554, 0.811, -126.568),
		Vector3(-1.0, 0.0, 0.0),
		120,
		func(pos: Vector3) -> bool: return pos.x < -35.0 and pos.y > 4.2
	)
	await _test_path(
		"upper stairs right edge",
		Vector3(-29.554, 0.811, -127.093),
		Vector3(-1.0, 0.0, 0.0),
		120,
		func(pos: Vector3) -> bool: return pos.x < -35.0 and pos.y > 4.2
	)
	await _test_path(
		"upper stairs descend",
		Vector3(-34.2, 4.378, -126.568),
		Vector3(1.0, 0.0, 0.0),
		120,
		func(pos: Vector3) -> bool: return pos.x > -30.0 and pos.y < 1.3
	)
	await _test_path(
		"basement stairs descend",
		Vector3(-34.2, 0.81, -126.568),
		Vector3(1.0, 0.0, 0.0),
		120,
		func(pos: Vector3) -> bool: return pos.x > -30.0 and pos.y < -2.3
	)
	await _test_path(
		"front doorstep",
		Vector3(-29.0, 0.811, -114.5),
		Vector3(0.0, 0.0, -1.0),
		90,
		func(pos: Vector3) -> bool: return pos.z < -116.0
	)
	await _test_path(
		"front doorway right enter",
		Vector3(-28.28, 0.811, -114.5),
		Vector3(0.0, 0.0, -1.0),
		90,
		func(pos: Vector3) -> bool: return pos.z < -117.0
	)
	await _test_path(
		"front doorway right exit",
		Vector3(-28.28, 0.811, -118.069),
		Vector3(0.0, 0.0, 1.0),
		90,
		func(pos: Vector3) -> bool: return pos.z > -115.0
	)
	await _test_path(
		"interior doorway glancing entry",
		Vector3(-48.237, 0.811, -123.996),
		Vector3(-0.761, 0.0, -0.648).normalized(),
		45,
		func(pos: Vector3) -> bool: return pos.distance_to(Vector3(-48.237, 0.811, -123.996)) > 0.75
	)
	await _test_path(
		"synthetic 0.25m step",
		Vector3(99.0, 1.001, 100.0),
		Vector3(1.0, 0.0, 0.0),
		40,
		func(pos: Vector3) -> bool: return pos.x > 101.5 and pos.y > 1.18
	)
	await _test_path(
		"synthetic narrow doorway",
		Vector3(99.0, 1.001, 108.0),
		Vector3(1.0, 0.0, 0.0),
		75,
		func(pos: Vector3) -> bool: return pos.x > 102.0
	)
	await _test_path(
		"synthetic 0.50m obstacle stays blocked",
		Vector3(99.0, 1.001, 104.0),
		Vector3(1.0, 0.0, 0.0),
		60,
		func(pos: Vector3) -> bool: return pos.x < 99.8 and pos.y < 1.1
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


func _verify_front_door(map: Node) -> void:
	var door := map.find_child("FrontDoor", true, false) as InteractableDoor
	if door == null:
		failures.append("front door controller is missing")
		return
	var collision := door.find_child("InteractionCollision", true, false) as CollisionShape3D
	var box := collision.shape as BoxShape3D if collision != null else null
	if box == null:
		failures.append("front door box collision is missing")
		return
	if box.size.x < 0.9 or box.size.y < 2.0 or box.size.z < 0.04:
		failures.append("front door collision has unexpected size %s" % box.size)
	var door_mesh := door.find_child("Puerta", true, false) as MeshInstance3D
	door.set_highlighted(true)
	if door_mesh == null or not door_mesh.get_layer_mask_value(20):
		failures.append("front door interaction outline is missing")
	door.set_highlighted(false)
	door.set_open_immediate(true)
	if absf(door.rotation_degrees.y) < 90.0:
		failures.append("front door did not open")
	print("[DOOR_TEST] collision=%s open_angle=%.1f" % [box.size, door.rotation_degrees.y])


func _verify_interactables(map: Node) -> void:
	var moving_count := 0
	var light_count := 0
	var television_count := 0
	var cabinet_part_count := 0
	var cabinet_lid_count := 0
	var window_count := 0
	var van_door_count := 0
	var laundry_count := 0
	var refrigerator_count := 0
	for candidate: Node in get_tree().get_nodes_in_group("interactable"):
		if not map.is_ancestor_of(candidate):
			continue
		if candidate is MovingInteractable:
			var moving := candidate as MovingInteractable
			moving_count += 1
			if moving.moving_collision == null:
				failures.append("%s has no moving collision" % moving.name)
			_verify_interactable_outline(moving)
			var initial_transform := moving.transform
			var initial_progress := moving.movement_progress
			var initial_target := moving.target_progress
			var initial_is_open := moving.is_open
			moving.set_open_immediate(false)
			var closed := moving.transform
			var closed_center := moving.to_global(moving.moving_collision.position)
			moving.set_open_immediate(true)
			if moving.transform.is_equal_approx(closed):
				failures.append("%s does not animate" % moving.name)
			if moving.display_name in ["cabinet lid", "washer lid"]:
				var open_center := moving.to_global(moving.moving_collision.position)
				if open_center.y <= closed_center.y + 0.01:
					failures.append("%s does not open upward" % moving.name)
			moving.transform = initial_transform
			moving.movement_progress = initial_progress
			moving.target_progress = initial_target
			moving.is_open = initial_is_open
			match moving.display_name:
				"cabinet door", "drawer": cabinet_part_count += 1
				"cabinet lid":
					cabinet_part_count += 1
					cabinet_lid_count += 1
				"window": window_count += 1
				"van door", "van side door", "van rear door": van_door_count += 1
				"washer lid", "dryer door": laundry_count += 1
				"freezer door", "refrigerator door": refrigerator_count += 1
		elif candidate is TelevisionInteractable:
			television_count += 1
			_verify_television_screen(candidate as TelevisionInteractable)
		elif candidate is LightInteractable:
			var lamp := candidate as LightInteractable
			light_count += 1
			_verify_interactable_outline(lamp)
			lamp.set_on_immediate(false)
			if lamp.controlled_light == null or lamp.controlled_light.visible:
				failures.append("%s does not turn off" % lamp.name)
			lamp.set_on_immediate(true)
	if cabinet_part_count != 59:
		failures.append("expected 59 cabinet parts, found %d" % cabinet_part_count)
	if cabinet_lid_count != 0:
		failures.append("expected no cabinet lids, found %d" % cabinet_lid_count)
	if window_count != 0:
		failures.append("expected no interactive windows, found %d" % window_count)
	if van_door_count != 5:
		failures.append("expected 5 van doors, found %d" % van_door_count)
	if laundry_count != 4:
		failures.append("expected 4 laundry doors/lids, found %d" % laundry_count)
	if refrigerator_count != 2:
		failures.append("expected 2 refrigerator doors, found %d" % refrigerator_count)
	if light_count != 38:
		failures.append("expected 38 interactive lamps, found %d" % light_count)
	if television_count != 4:
		failures.append("expected 4 interactive televisions, found %d" % television_count)
	if moving_count != 71:
		failures.append("expected 71 moving interactables, found %d" % moving_count)
	_verify_imported_drawer_states(map)
	_verify_explicit_cabinet_classification(map)
	_verify_van_doors_are_exterior_only(map)
	_verify_moving_interaction_reversal(map)
	print("[INTERACTABLE_TEST] moving=%d lights=%d televisions=%d cabinets=%d lids=%d windows=%d van=%d laundry=%d refrigerator=%d" % [
		moving_count,
		light_count,
		television_count,
		cabinet_part_count,
		cabinet_lid_count,
		window_count,
		van_door_count,
		laundry_count,
		refrigerator_count,
	])


func _verify_moving_interaction_reversal(map: Node) -> void:
	var moving := map.find_child("Sliding_*", true, false) as MovingInteractable
	if moving == null:
		failures.append("no sliding interactable available for reversal test")
		return
	moving.set_open_immediate(false)
	if not moving.interact(null):
		failures.append("%s did not start opening" % moving.name)
		return
	moving._physics_process(0.1)
	if not moving.interact(null) or moving.target_progress != 0.0:
		failures.append("%s could not reverse and close" % moving.name)
	moving.set_open_immediate(false)


func _verify_imported_drawer_states(map: Node) -> void:
	var drawer := map.find_child("Sliding_P_001", true, false) as SlidingInteractable
	var cabinet := map.find_child("Cofre", true, false) as MeshInstance3D
	if drawer == null or cabinet == null or drawer.moving_collision == null:
		failures.append("P_001 drawer or its Cofre cabinet is missing")
		return
	var drawer_center := drawer.global_transform * drawer.moving_collision.position
	var cabinet_center := cabinet.global_transform * cabinet.get_aabb().get_center()
	var slide_offset := absf(
		(drawer_center - cabinet_center).dot(drawer.slide_axis_world)
	)
	if slide_offset > 0.02:
		failures.append("P_001 drawer starts %.3fm outside Cofre" % slide_offset)
	if drawer.movement_progress != 0.0 or drawer.is_open:
		failures.append("P_001 drawer does not start closed")
	var half_open := map.find_child("Sliding_p_058", true, false) as SlidingInteractable
	if half_open == null or half_open.movement_progress <= 0.0 or half_open.is_open:
		failures.append("p_058 is not preserved as a partially open drawer")
	var fully_open := map.find_child("Sliding_p_038", true, false) as SlidingInteractable
	if fully_open == null or not fully_open.is_open:
		failures.append("p_038 does not start as an open drawer")


func _verify_explicit_cabinet_classification(map: Node) -> void:
	for mesh_name in [&"p_029", &"p_061", &"p_062"]:
		var mesh := map.find_child(mesh_name, true, false) as MeshInstance3D
		var body := mesh.get_parent() as MovingInteractable if mesh != null else null
		if body == null or not body is HingedInteractable or body.display_name != "cabinet door":
			failures.append("%s is not classified as a cabinet door" % mesh_name)
	var rail := map.find_child("p_041", true, false) as MeshInstance3D
	if rail != null and rail.get_parent().is_in_group("interactable"):
		failures.append("p_041 shower rail is still interactive")


func _verify_van_doors_are_exterior_only(map: Node) -> void:
	for candidate: Node in get_tree().get_nodes_in_group("interactable"):
		if not map.is_ancestor_of(candidate) or not candidate is MovingInteractable:
			continue
		var door := candidate as MovingInteractable
		if not door.display_name.begins_with("van"):
			continue
		if door.interaction_normal_local.is_zero_approx() or door.moving_collision == null:
			failures.append("%s has no exterior interaction side" % door.name)
			continue
		var normal := (
			door.global_transform.basis * door.interaction_normal_local
		).normalized()
		var center := door.global_transform * door.moving_collision.position
		if not door.can_interact_from(center + normal * 2.0):
			failures.append("%s rejects its exterior side" % door.name)
		if door.can_interact_from(center - normal * 2.0):
			failures.append("%s accepts interaction through the van" % door.name)
		door.set_open_immediate(true)
		if not door.can_interact_from(center - normal * 2.0):
			failures.append("%s cannot be selected from its visible reverse side while open" % door.name)
		door.set_open_immediate(false)


func _verify_television_screen(television: TelevisionInteractable) -> void:
	if television.find_child("TelevisionScreen", true, false) != null:
		failures.append("%s still uses overlay screen geometry" % television.name)
	if television.screen_material == null:
		failures.append("%s has no atlas screen material" % television.name)
		return
	if television.screen_material.shader.resource_path != "res://material/television_screen.gdshader":
		failures.append("%s does not use the TV screen shader" % television.name)
	if television.screen_material.get_shader_parameter("screen_mask_texture") == null:
		failures.append("%s has no curved screen mask" % television.name)
	if television.screen_light == null:
		failures.append("%s has no screen light" % television.name)
	television.set_on_immediate(true)
	if float(television.screen_material.get_shader_parameter("screen_power")) != 1.0:
		failures.append("%s screen does not turn on" % television.name)
	if television.screen_light == null or not television.screen_light.visible:
		failures.append("%s screen light does not turn on" % television.name)
	television.set_on_immediate(false)
	if television.screen_light != null and television.screen_light.visible:
		failures.append("%s screen light does not turn off" % television.name)


func _verify_airborne_wedge_recovery() -> void:
	var recovery_origin := Vector3(100.0, 1.001, 112.0)
	player.global_position = recovery_origin
	player.velocity = Vector3.ZERO
	player.vel_horizontal = Vector2.ZERO
	player.jump()
	player.global_position += Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	player.vel_vertical = 0.0
	for _frame in player.AIRBORNE_WEDGE_RECOVERY_FRAMES:
		player._recover_from_airborne_wedge(player.global_position)
	if not player.global_position.is_equal_approx(recovery_origin):
		failures.append("airborne wedge recovery did not return to the safe jump origin")
	if player.jump_recovery_valid or player.vel_vertical != 0.0:
		failures.append("airborne wedge recovery did not reset jump state")


func _verify_interactable_outline(interactable: Node) -> void:
	var visuals := interactable.find_children("*", "MeshInstance3D", true, false)
	var visual := visuals[0] as MeshInstance3D if not visuals.is_empty() else null
	interactable.call("set_highlighted", true)
	if visual == null or not visual.get_layer_mask_value(20):
		failures.append("%s has no interaction outline" % interactable.name)
	interactable.call("set_highlighted", false)


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


func _verify_static_box_collision(map: Node, mesh_name: String) -> void:
	var mesh := map.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh == null:
		failures.append("%s mesh is missing" % mesh_name)
		return
	var body := mesh.find_child("%sCollision" % mesh_name, false, false) as StaticBody3D
	var collision: CollisionShape3D = null
	if body != null:
		collision = body.find_child("*", false, false) as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		failures.append("%s does not have static box collision" % mesh_name)
	if mesh.get_parent().is_in_group("interactable"):
		failures.append("%s is still interactive" % mesh_name)


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
	test_name: String,
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
	for _frame in frames:
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
		test_name,
		result,
		player.global_position,
		step_count,
		longest_stall,
		max_camera_rise,
		player.step_debug_reason,
	])
	if not result:
		failures.append("%s failed at %s (%s)" % [test_name, player.global_position, player.step_debug_reason])


func _add_synthetic_course() -> void:
	_add_box("SyntheticFloor", Vector3(102.0, -0.1, 104.0), Vector3(10.0, 0.2, 14.0))
	_add_box("ShortStep", Vector3(101.0, 0.125, 100.0), Vector3(2.0, 0.25, 2.5))
	_add_box("TallObstacle", Vector3(101.0, 0.25, 104.0), Vector3(2.0, 0.5, 2.5))
	_add_box("DoorwayLeft", Vector3(101.5, 1.5, 107.59), Vector3(3.0, 3.0, 0.2))
	_add_box("DoorwayRight", Vector3(101.5, 1.5, 108.41), Vector3(3.0, 3.0, 0.2))


func _add_box(body_name: String, body_position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = body_position
	body.add_child(collision)
	add_child(body)
