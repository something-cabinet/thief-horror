extends Node3D

# Automated regression test (not used by the game). Run _step_solver_test.tscn directly,
# or headless: godot --headless res://level/_step_solver_test.tscn
# Checks:
#   - Level1 player spawn position/yaw/pitch.
#   - Collision setup on specific map meshes (trimesh vs. box, non-interactive props).
#   - Interactables: expected counts, open/close animation, outlines, lamps, TVs,
#     drawer start states, van doors, front door, red side door.
#   - Player movement: walks a physics-driven player through stairs, doorways and a
#     synthetic step/obstacle course, checking step-up works, tall obstacles block,
#     and the camera doesn't jerk upward.
# Prints [..._TEST] lines; quits with exit code 0 if everything passes, 1 on any failure.
# NOTE: expected counts and coordinates are hard-coded, so update them when the map changes.

const MAP_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const PLAYER_SCENE := preload("res://entity/player/Player.tscn")
const LEVEL_SCENE := preload("res://level/Level1.tscn")
const GRANDMA_SCENE := preload("res://entity/npc/GrandmaNpc.tscn")
const GRANDMA_MODEL := preload("res://asset/model/characters/grandma/Grandma.fbx")
const HUMANOID_ANIMATIONS := preload("res://asset/animation/humanoid/mesh2motion_human_base.glb")
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
	_verify_red_side_door(map)

	player = PLAYER_SCENE.instantiate() as Player
	player.collision_layer = 4
	player.collision_mask = 1
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _verify_house_navigation(map)
	await _verify_granny_porch()
	await _verify_granny_upper_stair()
	await _verify_interaction_line_of_sight()
	await _verify_grandma_gait()

	_add_synthetic_course()
	await get_tree().physics_frame
	_verify_airborne_wedge_recovery()
	await _verify_blocked_jump_recovery()

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
		"upper bathroom doorway seam",
		Vector3(-35.078, 4.379, -136.962),
		Vector3.RIGHT,
		60,
		func(pos: Vector3) -> bool: return pos.x > -33.5
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
	var expected_position := Vector3(-31.71, -0.187, -104.284)
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


func _verify_blocked_jump_recovery() -> void:
	player.global_position = Vector3(-35.078, 4.379, -136.962)
	for _frame in 4:
		player.velocity = Vector3.DOWN
		player.move_and_slide()
		await get_tree().physics_frame
	var start_y := player.global_position.y
	player.jumped = true
	player.vel_vertical = Player.JUMP_FORCE
	player.velocity = Vector3.UP * Player.JUMP_FORCE
	player.move_and_slide()
	player._sync_vertical_state_after_move(start_y)
	if player.vel_vertical > 0.0 or player.jumped:
		failures.append("blocked low-header jump leaves the player wedged")
	print("[BLOCKED_JUMP_TEST] xyz=%s floor=%s vertical=%.1f result=%s" % [
		player.global_position,
		player.is_on_floor(),
		player.vel_vertical,
		player.step_debug_reason,
	])


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


func _verify_red_side_door(map: Node) -> void:
	var door := map.find_child("RedSideDoor", true, false) as InteractableDoor
	if door == null:
		failures.append("red side door controller is missing")
		return
	var collision := door.find_child("InteractionCollision", true, false) as CollisionShape3D
	var box := collision.shape as BoxShape3D if collision != null else null
	if box == null or box.size.x > 0.12 or box.size.y < 2.0 or box.size.z < 0.9:
		failures.append("red side door collision has unexpected size %s" % [box.size if box else null])
	var door_mesh := door.find_child("RedSideDoorMesh", true, false) as MeshInstance3D
	var material := door_mesh.get_active_material(0) as StandardMaterial3D if door_mesh else null
	if material == null or material.albedo_color.r < material.albedo_color.g * 4.0:
		failures.append("red side door material is missing or not red")
	door.set_open_immediate(true)
	if absf(door.rotation_degrees.y) < 90.0:
		failures.append("red side door did not open")
	print("[RED_DOOR_TEST] collision=%s open_angle=%.1f" % [
		box.size if box else Vector3.ZERO,
		door.rotation_degrees.y,
	])


func _verify_house_navigation(map: Node) -> void:
	var region := map.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if region == null or region.navigation_mesh == null:
		failures.append("house navigation region is missing")
		return
	for _frame in 20:
		await get_tree().physics_frame
	var navigation_map := region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var entry_path := NavigationServer3D.map_get_path(
		navigation_map,
		Vector3(-30.65, -1.17, -103.37),
		Vector3(-28.28, 0.81, -120.48),
		true
	)
	var stair_path := NavigationServer3D.map_get_path(
		navigation_map,
		Vector3(-28.28, 0.81, -120.48),
		Vector3(-36.18, 4.38, -126.57),
		true
	)
	var doorway_path := NavigationServer3D.map_get_path(
		navigation_map,
		Vector3(-28.48, -0.1, -116.0),
		Vector3(-28.48, -0.1, -119.0),
		true
	)
	if entry_path.size() < 2:
		failures.append("house navigation cannot reach the interior")
	else:
		var reaches_front_link := false
		for point: Vector3 in entry_path:
			if point.distance_to(Vector3(-28.48, -0.1, -117.5)) < 0.1:
				reaches_front_link = true
				break
		if not reaches_front_link:
			failures.append("entry A* path bypasses the front-door threshold")
	if stair_path.size() < 2:
		failures.append("house navigation cannot reach the upper floor")
	if doorway_path.size() < 2:
		failures.append("A* cannot cross the front-door threshold")
	else:
		for point: Vector3 in doorway_path:
			if absf(point.x + 28.48) > 0.5:
				failures.append("front-door A* path detours around the house")
				break
	var original_player_position := player.global_position
	player.global_position = Vector3(-27.042, 0.809, -123.252)
	var target_probe := GRANDMA_SCENE.instantiate() as GrandmaNpc
	target_probe.name = "NavigationTargetProbe"
	target_probe.position = Vector3(-28.0, -0.1, -120.0)
	add_child(target_probe)
	target_probe.follow_target = player
	var exact_target := target_probe._follow_target_ground_position()
	var selected_target := target_probe._select_follow_navigation_target(exact_target)
	if not selected_target.is_finite():
		failures.append("granny cannot project the wall-adjacent player onto navigation")
	elif not target_probe._follow_navigation_target_is_visible(
		exact_target,
		selected_target
	):
		failures.append("granny navigation target projects through a wall")
	elif not target_probe._follow_navigation_target_has_clearance(selected_target):
		failures.append("granny navigation target has no body clearance")
	target_probe.free()
	player.global_position = original_player_position
	print("[NAVIGATION_TEST] polygons=%d entry=%d stairs=%d doorway=%d target=%s" % [
		region.navigation_mesh.get_polygon_count(),
		entry_path.size(),
		stair_path.size(),
		doorway_path.size(),
		selected_target,
	])


func _verify_granny_porch() -> void:
	var target := Node3D.new()
	target.name = "GrannyPorchTarget"
	target.position = Vector3(-28.48, -0.1, -116.8)
	add_child(target)
	var granny := GRANDMA_SCENE.instantiate() as GrandmaNpc
	granny.name = "GrannyPorchTest"
	granny.position = Vector3(-28.48, -0.55, -114.0)
	granny.follow_target_path = NodePath("../GrannyPorchTarget")
	granny.follow_distance = 0.15
	granny.follow_speed = 1.2
	granny.catch_up_speed = 1.2
	granny.catch_up_distance = 100.0
	add_child(granny)
	for _frame in 180:
		await get_tree().physics_frame
	if granny.global_position.z > -116.3 or granny.global_position.y < -0.3:
		failures.append("granny cannot step onto the front porch: %s" % granny.global_position)
	print("[GRANNY_PORCH_TEST] xyz=%s step=%s" % [
		granny.global_position,
		granny.last_step_result,
	])
	granny.free()
	target.free()


func _verify_granny_upper_stair() -> void:
	var original_player_position := player.global_position
	player.global_position = Vector3(-31.937, 4.379, -124.379)
	var granny := GRANDMA_SCENE.instantiate() as GrandmaNpc
	granny.name = "GrannyUpperStairTest"
	granny.position = Vector3(-33.735, 3.045, -126.634)
	granny.follow_target_path = NodePath("../Player")
	granny.catch_up_distance = 100.0
	add_child(granny)
	for _frame in 150:
		await get_tree().physics_frame
	if granny.global_position.y < 3.34 or granny.global_position.z < -125.8:
		failures.append("granny loops on the upper stair corner: %s" % granny.global_position)
	print("[GRANNY_UPPER_STAIR_TEST] xyz=%s step=%s" % [
		granny.global_position,
		granny.last_step_result,
	])
	granny.free()
	player.global_position = original_player_position


func _verify_interactables(map: Node) -> void:
	var van_mesh := map.find_child("Ban", true, false) as MeshInstance3D
	var van_center := van_mesh.global_transform * van_mesh.get_aabb().get_center()
	var front_door := map.find_child("FrontDoor", true, false) as Node3D
	var van_side_door := map.find_child("Hinged_Puerta_Late", true, false) as Node3D
	if front_door == null or van_side_door == null:
		failures.append("front-door van staging nodes are missing")
	elif absf(front_door.global_position.x - van_side_door.global_position.x) > 0.05:
		failures.append("van side door is not aligned with the house front door")
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
				"van door", "van side door", "van rear door":
					van_door_count += 1
					var hinged := moving as HingedInteractable
					if hinged.choose_direction_from_actor:
						failures.append("%s can incorrectly swing inward" % moving.name)
					var open_center := moving.to_global(moving.moving_collision.position)
					if open_center.distance_squared_to(van_center) < closed_center.distance_squared_to(van_center):
						failures.append("%s opens toward the van" % moving.name)
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
	if moving_count != 72:
		failures.append("expected 72 moving interactables, found %d" % moving_count)
	_verify_imported_drawer_states(map)
	_verify_explicit_cabinet_classification(map)
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


func _verify_interaction_line_of_sight() -> void:
	var target := _add_box(
		"InteractionVisibilityTarget",
		Vector3(200.0, 1.0, 204.0),
		Vector3.ONE
	)
	target.add_to_group("interactable")
	var blocker := _add_box(
		"InteractionVisibilityBlocker",
		Vector3(200.0, 1.0, 202.0),
		Vector3.ONE
	)
	await get_tree().physics_frame
	var ray_start := Vector3(200.0, 1.0, 200.0)
	var ray_end := Vector3(200.0, 1.0, 206.0)
	if player._find_visible_interactable(ray_start, ray_end) != null:
		failures.append("interaction ray selects a target through an obstruction")
	blocker.collision_layer = 0
	await get_tree().physics_frame
	if player._find_visible_interactable(ray_start, ray_end) != target:
		failures.append("interaction ray rejects an unobstructed target")
	target.queue_free()
	blocker.queue_free()


func _verify_grandma_gait() -> void:
	var gait_navigation_mesh := NavigationMesh.new()
	gait_navigation_mesh.cell_size = 0.15
	gait_navigation_mesh.cell_height = 0.05
	gait_navigation_mesh.vertices = PackedVector3Array([
		Vector3(296.0, 0.0, 291.0),
		Vector3(296.0, 0.0, 309.0),
		Vector3(304.0, 0.0, 309.0),
		Vector3(304.0, 0.0, 291.0),
	])
	gait_navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var gait_navigation := NavigationRegion3D.new()
	gait_navigation.name = "GrandmaGaitNavigation"
	gait_navigation.navigation_mesh = gait_navigation_mesh
	gait_navigation.use_edge_connections = false
	add_child(gait_navigation)
	var floor := _add_box(
		"GrandmaGaitFloor",
		Vector3(300.0, -0.1, 300.0),
		Vector3(8.0, 0.2, 16.0)
	)
	var target := Node3D.new()
	target.name = "GrandmaWalkTarget"
	target.position = Vector3(300.0, 0.0, 292.0)
	add_child(target)
	var grandma := GRANDMA_SCENE.instantiate() as GrandmaNpc
	grandma.name = "GrandmaGaitTest"
	grandma.position = Vector3(300.0, 0.01, 304.0)
	grandma.model_scene = GRANDMA_MODEL
	grandma.animation_library = HUMANOID_ANIMATIONS
	grandma.follow_target_path = NodePath("../GrandmaWalkTarget")
	grandma.follow_distance = 0.2
	grandma.follow_speed = 0.65
	grandma.catch_up_distance = 100.0
	add_child(grandma)
	await get_tree().physics_frame
	await get_tree().process_frame
	if grandma.navigation_agent == null:
		failures.append("granny navigation agent was not created")
	elif not grandma.navigation_agent.avoidance_enabled:
		failures.append("granny local avoidance is disabled")
	grandma.set_navigation_debug_visible(true)
	if grandma.navigation_debug_instance == null or not grandma.navigation_debug_instance.visible:
		failures.append("granny F3 navigation path debug is unavailable")
	grandma.set_navigation_debug_visible(false)
	if grandma.left_foot_ik == null or grandma.right_foot_ik == null:
		failures.append("grandma foot planting IK was not created")
		grandma.free()
		target.free()
		floor.free()
		gait_navigation.free()
		return
	# Let the initial idle-to-walk blend finish before measuring a complete gait.
	for _frame in 90:
		await get_tree().physics_frame

	var left_metrics := {
		"samples": 0,
		"active": false,
		"last_target": Vector3.ZERO,
		"max_target_drift": 0.0,
		"max_foot_error": 0.0,
	}
	var right_metrics := left_metrics.duplicate(true)
	grandma.left_foot_ik.modification_processed.connect(
		_record_grandma_foot_plant.bind(grandma, true, left_metrics)
	)
	grandma.right_foot_ik.modification_processed.connect(
		_record_grandma_foot_plant.bind(grandma, false, right_metrics)
	)
	var start_position := grandma.global_position
	for _frame in 180:
		await get_tree().physics_frame
	var traveled := grandma.global_position.distance_to(start_position)
	var measured_speed := traveled / 3.0
	var expected_animation_scale := grandma.follow_speed / grandma.WALK_ANIMATION_REFERENCE_SPEED
	if not is_equal_approx(grandma.animation_player.speed_scale, expected_animation_scale):
		failures.append("grandma walk cadence is not synchronized to movement speed")
	for metrics in [left_metrics, right_metrics]:
		if int(metrics.samples) < 10:
			failures.append("grandma foot planting did not produce enough stance samples")
		if float(metrics.max_foot_error) > 0.01:
			failures.append("grandma planted foot misses its target by %.4fm" % metrics.max_foot_error)
		if float(metrics.max_target_drift) > 0.001:
			failures.append("grandma foot target drifts %.4fm during stance" % metrics.max_target_drift)
	if measured_speed < 0.60 or measured_speed > 0.70:
		failures.append("grandma follow speed is %.3fm/s" % measured_speed)
	print("[GRANDMA_GAIT_TEST] speed=%.3f scale=%.3f left_error=%.4f right_error=%.4f" % [
		measured_speed,
		grandma.animation_player.speed_scale,
		left_metrics.max_foot_error,
		right_metrics.max_foot_error,
	])
	grandma.free()
	target.free()
	floor.free()
	gait_navigation.free()


func _record_grandma_foot_plant(
	grandma: GrandmaNpc,
	is_left: bool,
	metrics: Dictionary
) -> void:
	var ik := grandma.left_foot_ik if is_left else grandma.right_foot_ik
	if ik.influence < 0.999:
		metrics.active = false
		return
	var target := grandma.left_foot_target if is_left else grandma.right_foot_target
	var foot_bone := grandma.left_foot_bone if is_left else grandma.right_foot_bone
	var foot_position := grandma.skeleton.to_global(
		grandma.skeleton.get_bone_global_pose(foot_bone).origin
	)
	metrics.samples = int(metrics.samples) + 1
	metrics.max_foot_error = maxf(
		float(metrics.max_foot_error),
		foot_position.distance_to(target.global_position)
	)
	if bool(metrics.active):
		metrics.max_target_drift = maxf(
			float(metrics.max_target_drift),
			target.global_position.distance_to(metrics.last_target as Vector3)
		)
	metrics.active = true
	metrics.last_target = target.global_position


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


func _add_box(body_name: String, body_position: Vector3, size: Vector3) -> StaticBody3D:
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
	return body
