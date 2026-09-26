extends CharacterBody3D
class_name GrandmaNpc

const HUMANOID_LIBRARY := &"humanoid"
const IDLE_ANIMATION := &"humanoid/Idle_A"
const TALK_ANIMATION := &"humanoid/Idle_Talking"
const SEATED_IDLE_ANIMATION := &"humanoid/Sitting_Idle"
const SEATED_TALK_ANIMATION := &"humanoid/Sitting_Talking"
const IDLE_ANIMATIONS := [
	&"humanoid/Idle_A",
	&"humanoid/Idle_Talking",
	&"humanoid/Idle_ShakeOff",
]
const WALK_ANIMATION := &"humanoid/Walk"
# Measured from the planted halves of the retargeted Walk clip.
const WALK_ANIMATION_REFERENCE_SPEED := 0.70
const FOOT_STANCE_PORTION := 0.5
const FOOT_PLANT_BLEND_PORTION := 0.06
const FOOT_GROUND_CLEARANCE := 0.085
const FOLLOW_MAX_STEP_HEIGHT := 0.35
const FOLLOW_SAME_LEVEL_HEIGHT := 0.55
const FOLLOW_REPATH_INTERVAL := 0.25
const FOLLOW_REPATH_DISTANCE := 0.35
const FOLLOW_STUCK_REPATH_TIME := 1.0
const FOLLOW_TARGET_SAMPLE_STEP := 0.35
const FOLLOW_TARGET_SAMPLE_RINGS := 4
const FOLLOW_TARGET_SAMPLE_DIRECTIONS := 12
const FOLLOW_TARGET_SAMPLE_ERROR := 0.22
const FOLLOW_TARGET_MAX_HEIGHT_DELTA := 0.65
const FOLLOW_TARGET_CLEARANCE_LIFT := 0.025
const NAVIGATION_DEBUG_HEIGHT := 0.10
const NAVIGATION_DEBUG_POINT_SIZE := 0.12

@export var display_name := "Granny"
@export var model_scene: PackedScene
@export var animation_library: AnimationLibrary
@export var greeting_dialogue: DialogueResource
@export var dialogue_title := "start"
@export var seated := false
@export var follow_target_path: NodePath
@export var follow_distance := 1.5
@export var follow_speed := 0.65
@export var catch_up_distance := 4.0
@export var catch_up_speed := 0.9
@export var random_seed_offset := 0
@export var walk_speed := 0.55
@export var wander_radius := 2.0
@export var minimum_idle_time := 1.5
@export var maximum_idle_time := 4.0
@export var minimum_walk_time := 1.5
@export var maximum_walk_time := 3.5

@onready var model_anchor: Node3D = $ModelAnchor
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var model_instance: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var left_foot_ik: TwoBoneIK3D
var right_foot_ik: TwoBoneIK3D
var left_foot_target: Node3D
var right_foot_target: Node3D
var left_knee_pole: Node3D
var right_knee_pole: Node3D
var left_upper_leg_bone := -1
var left_lower_leg_bone := -1
var left_foot_bone := -1
var right_upper_leg_bone := -1
var right_lower_leg_bone := -1
var right_foot_bone := -1
var left_foot_planted := false
var right_foot_planted := false
var random := RandomNumberGenerator.new()
var spawn_position := Vector3.ZERO
var wander_direction := Vector3.ZERO
var state_time_remaining := 0.0
var is_walking := false
var is_talking := false
var follow_target: Node3D
var navigation_target := Vector3(INF, INF, INF)
var navigation_source_target := Vector3(INF, INF, INF)
var navigation_target_clearance_shape: CapsuleShape3D
var last_step_result := ""
var navigation_repath_time := 0.0
var pending_navigation_delta := 0.0
var pending_navigation_motion := false
var follow_stuck_time := 0.0
var last_follow_position := Vector3.ZERO
var navigation_debug_mesh: ImmediateMesh
var navigation_debug_instance: MeshInstance3D
var navigation_debug_route_material: StandardMaterial3D
var navigation_debug_active_material: StandardMaterial3D
var navigation_debug_visible := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 1
	collision_mask = 5
	add_to_group("interactable")
	add_to_group("navigation_debuggable")
	_setup_navigation_debug()
	spawn_position = global_position
	random.seed = hash(global_position) + random_seed_offset
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path) as Node3D
	last_follow_position = global_position
	navigation_agent.target_desired_distance = follow_distance
	navigation_agent.max_speed = catch_up_speed
	navigation_target_clearance_shape = CapsuleShape3D.new()
	navigation_target_clearance_shape.radius = navigation_agent.radius * 0.9
	navigation_target_clearance_shape.height = navigation_agent.height * 0.95
	navigation_agent.avoidance_enabled = not seated and follow_target != null
	navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)
	if follow_target != null:
		call_deferred("_reset_navigation_target")

	if model_scene != null:
		model_instance = model_scene.instantiate() as Node3D
		model_anchor.add_child(model_instance)
		_cache_animation_player()
		_attach_animation_library()
		_configure_animation_loops()
		_setup_foot_planting()

	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	if dialogue_manager != null:
		dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)

	_begin_idle()


func _process(_delta: float) -> void:
	_update_foot_planting()
	_update_navigation_debug()


func _physics_process(delta: float) -> void:
	if seated:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if is_talking:
		pending_navigation_motion = false
		navigation_agent.velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_instance_valid(follow_target):
		_update_following(delta)
		return

	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		if is_walking:
			_begin_idle()
		else:
			_begin_walk()

	if is_walking:
		var offset_from_spawn := global_position - spawn_position
		offset_from_spawn.y = 0.0
		if offset_from_spawn.length() >= wander_radius:
			wander_direction = -offset_from_spawn.normalized()
		velocity.x = wander_direction.x * walk_speed
		velocity.z = wander_direction.z * walk_speed
		_face_direction(wander_direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 4.0 * delta)

	move_and_slide()
	if is_walking and is_on_wall():
		_begin_walk()


func interact(actor: Node3D) -> bool:
	is_talking = true
	_begin_idle()
	_play_animation(SEATED_TALK_ANIMATION if seated else TALK_ANIMATION)
	if not seated:
		_face_actor(actor)
	if greeting_dialogue != null:
		var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
		if dialogue_manager != null:
			dialogue_manager.show_dialogue_balloon(greeting_dialogue, dialogue_title)
	return true


func get_interaction_prompt() -> String:
	return "[E] Talk to %s" % display_name


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(model_instance, highlighted)


func set_navigation_debug_visible(debug_visible: bool) -> void:
	navigation_debug_visible = debug_visible and follow_target != null
	navigation_agent.debug_enabled = navigation_debug_visible
	if navigation_debug_instance != null:
		navigation_debug_instance.visible = navigation_debug_visible
	if not navigation_debug_visible and navigation_debug_mesh != null:
		navigation_debug_mesh.clear_surfaces()


func _setup_navigation_debug() -> void:
	navigation_debug_mesh = ImmediateMesh.new()
	navigation_debug_instance = MeshInstance3D.new()
	navigation_debug_instance.name = "NavigationPathDebug"
	navigation_debug_instance.mesh = navigation_debug_mesh
	navigation_debug_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	navigation_debug_instance.visible = false
	add_child(navigation_debug_instance)
	navigation_debug_instance.top_level = true
	navigation_debug_instance.global_transform = Transform3D.IDENTITY
	navigation_debug_route_material = _make_navigation_debug_material(
		Color(0.08, 1.0, 0.72, 1.0)
	)
	navigation_debug_active_material = _make_navigation_debug_material(
		Color(1.0, 0.72, 0.08, 1.0)
	)


func _make_navigation_debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.no_depth_test = true
	return material


func _update_navigation_debug() -> void:
	if not navigation_debug_visible or navigation_debug_mesh == null:
		return
	navigation_debug_mesh.clear_surfaces()
	var path := navigation_agent.get_current_navigation_path()
	if path.is_empty():
		return
	var path_index := clampi(
		navigation_agent.get_current_navigation_path_index(),
		0,
		path.size() - 1
	)
	var height_offset := Vector3.UP * NAVIGATION_DEBUG_HEIGHT
	navigation_debug_mesh.surface_begin(
		Mesh.PRIMITIVE_LINE_STRIP,
		navigation_debug_route_material
	)
	navigation_debug_mesh.surface_add_vertex(global_position + height_offset)
	for point_index in range(path_index, path.size()):
		navigation_debug_mesh.surface_add_vertex(path[point_index] + height_offset)
	navigation_debug_mesh.surface_end()

	navigation_debug_mesh.surface_begin(
		Mesh.PRIMITIVE_LINES,
		navigation_debug_route_material
	)
	for point_index in range(path_index, path.size()):
		var point: Vector3 = path[point_index] + height_offset
		navigation_debug_mesh.surface_add_vertex(
			point - Vector3.RIGHT * NAVIGATION_DEBUG_POINT_SIZE
		)
		navigation_debug_mesh.surface_add_vertex(
			point + Vector3.RIGHT * NAVIGATION_DEBUG_POINT_SIZE
		)
		navigation_debug_mesh.surface_add_vertex(
			point - Vector3.FORWARD * NAVIGATION_DEBUG_POINT_SIZE
		)
		navigation_debug_mesh.surface_add_vertex(
			point + Vector3.FORWARD * NAVIGATION_DEBUG_POINT_SIZE
		)
	navigation_debug_mesh.surface_end()

	navigation_debug_mesh.surface_begin(
		Mesh.PRIMITIVE_LINES,
		navigation_debug_active_material
	)
	navigation_debug_mesh.surface_add_vertex(global_position + height_offset)
	navigation_debug_mesh.surface_add_vertex(path[path_index] + height_offset)
	navigation_debug_mesh.surface_end()


func _cache_animation_player() -> void:
	var players := model_instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	animation_player = players[0] as AnimationPlayer
	var skeletons := model_instance.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0] as Skeleton3D


func _attach_animation_library() -> void:
	if animation_player == null or animation_library == null:
		return
	if animation_player.has_animation_library(HUMANOID_LIBRARY):
		animation_player.remove_animation_library(HUMANOID_LIBRARY)
	animation_player.add_animation_library(HUMANOID_LIBRARY, animation_library)


func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	for animation_name in IDLE_ANIMATIONS + [
		WALK_ANIMATION,
		SEATED_IDLE_ANIMATION,
		SEATED_TALK_ANIMATION,
	]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _begin_idle() -> void:
	is_walking = false
	velocity.x = 0.0
	velocity.z = 0.0
	state_time_remaining = random.randf_range(minimum_idle_time, maximum_idle_time)
	if seated:
		_play_animation(SEATED_IDLE_ANIMATION)
		return
	var idle_animation: StringName = IDLE_ANIMATIONS[random.randi_range(0, IDLE_ANIMATIONS.size() - 1)]
	_play_animation(idle_animation)


func _begin_walk() -> void:
	if seated:
		_begin_idle()
		return
	is_walking = true
	state_time_remaining = random.randf_range(minimum_walk_time, maximum_walk_time)
	var offset_from_spawn := global_position - spawn_position
	offset_from_spawn.y = 0.0
	if offset_from_spawn.length() >= wander_radius * 0.75:
		wander_direction = -offset_from_spawn.normalized()
	else:
		var angle := random.randf_range(0.0, TAU)
		wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	_play_walk_animation(walk_speed)


func _update_following(delta: float) -> void:
	var target_ground_position := _follow_target_ground_position()
	var target_distance := global_position.distance_to(target_ground_position)
	if (
		_horizontal_distance_to(target_ground_position) <= follow_distance
		and absf(target_ground_position.y - global_position.y) <= FOLLOW_SAME_LEVEL_HEIGHT
	):
		pending_navigation_motion = false
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var slowed_speed := move_toward(horizontal_speed, 0.0, follow_speed * 3.0 * delta)
		if horizontal_speed > 0.0001:
			var slowdown_ratio := slowed_speed / horizontal_speed
			velocity.x *= slowdown_ratio
			velocity.z *= slowdown_ratio
		if slowed_speed > 0.05:
			is_walking = true
			_play_walk_animation(slowed_speed)
		elif is_walking:
			_begin_idle()
		navigation_agent.velocity = Vector3.ZERO
		move_and_slide()
		return

	_update_navigation_target(delta)
	var destination := _next_follow_position()
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		pending_navigation_motion = false
		navigation_agent.velocity = Vector3.ZERO
		velocity.x = move_toward(velocity.x, 0.0, follow_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, follow_speed * 3.0 * delta)
		move_and_slide()
		return
	direction = direction.normalized()
	var speed := catch_up_speed if target_distance >= catch_up_distance else follow_speed
	var desired_velocity := direction * speed
	if navigation_agent.avoidance_enabled:
		pending_navigation_delta = delta
		pending_navigation_motion = true
		navigation_agent.velocity = desired_velocity
	else:
		_apply_follow_velocity(desired_velocity, delta)


func _reset_navigation_target() -> void:
	if not is_instance_valid(follow_target):
		return
	var target_position := _follow_target_ground_position()
	navigation_target = _select_follow_navigation_target(target_position)
	if not navigation_target.is_finite():
		return
	navigation_source_target = target_position
	navigation_agent.target_position = navigation_target
	navigation_repath_time = FOLLOW_REPATH_INTERVAL


func _update_navigation_target(delta: float) -> void:
	navigation_repath_time -= delta
	var target_position := _follow_target_ground_position()
	if (
		navigation_repath_time > 0.0
		and navigation_source_target.is_finite()
		and navigation_source_target.distance_to(target_position) < FOLLOW_REPATH_DISTANCE
	):
		return
	var selected_target := _select_follow_navigation_target(target_position)
	if not selected_target.is_finite():
		return
	navigation_target = selected_target
	navigation_source_target = target_position
	navigation_agent.target_position = selected_target
	navigation_repath_time = FOLLOW_REPATH_INTERVAL


func _select_follow_navigation_target(target_ground_position: Vector3) -> Vector3:
	var navigation_map := navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return Vector3(INF, INF, INF)
	var best_candidate := Vector3(INF, INF, INF)
	var best_score := INF
	for sample_offset: Vector3 in _follow_navigation_sample_offsets():
		var sample_position := target_ground_position + sample_offset
		var candidate := NavigationServer3D.map_get_closest_point(
			navigation_map,
			sample_position
		)
		if not candidate.is_finite():
			continue
		var sample_error := _horizontal_distance_between(candidate, sample_position)
		if sample_error > FOLLOW_TARGET_SAMPLE_ERROR:
			continue
		if (
			absf(candidate.y - target_ground_position.y)
			> FOLLOW_TARGET_MAX_HEIGHT_DELTA
		):
			continue
		if not _follow_navigation_target_is_visible(
			target_ground_position,
			candidate
		):
			continue
		if not _follow_navigation_target_has_clearance(candidate):
			continue
		var score := (
			_horizontal_distance_between(candidate, target_ground_position)
			+ sample_error * 0.5
		)
		if score < best_score:
			best_score = score
			best_candidate = candidate
	return best_candidate


func _follow_navigation_sample_offsets() -> Array[Vector3]:
	var offsets: Array[Vector3] = [Vector3.ZERO]
	for ring_index in range(1, FOLLOW_TARGET_SAMPLE_RINGS + 1):
		var radius := FOLLOW_TARGET_SAMPLE_STEP * ring_index
		for direction_index in FOLLOW_TARGET_SAMPLE_DIRECTIONS:
			var angle := TAU * direction_index / FOLLOW_TARGET_SAMPLE_DIRECTIONS
			offsets.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return offsets


func _follow_navigation_target_is_visible(
	target_ground_position: Vector3,
	candidate: Vector3
) -> bool:
	var excluded: Array[RID] = [get_rid()]
	if follow_target is CollisionObject3D:
		excluded.append((follow_target as CollisionObject3D).get_rid())
	var check_height := navigation_agent.height * 0.5
	var query := PhysicsRayQueryParameters3D.create(
		target_ground_position + Vector3.UP * check_height,
		candidate + Vector3.UP * check_height,
		1,
		excluded
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _follow_navigation_target_has_clearance(candidate: Vector3) -> bool:
	if navigation_target_clearance_shape == null:
		return false
	var excluded: Array[RID] = [get_rid()]
	if follow_target is CollisionObject3D:
		excluded.append((follow_target as CollisionObject3D).get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = navigation_target_clearance_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		candidate + Vector3.UP * (
			navigation_target_clearance_shape.height * 0.5
			+ FOLLOW_TARGET_CLEARANCE_LIFT
		)
	)
	query.collision_mask = 1
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _next_follow_position() -> Vector3:
	var next_path_position := navigation_agent.get_next_path_position()
	if navigation_agent.get_current_navigation_path().size() >= 2:
		return next_path_position
	return global_position


func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	if not pending_navigation_motion or seated or is_talking:
		return
	pending_navigation_motion = false
	_apply_follow_velocity(safe_velocity, pending_navigation_delta)


func _apply_follow_velocity(follow_velocity: Vector3, delta: float) -> void:
	velocity.x = follow_velocity.x
	velocity.z = follow_velocity.z
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed <= 0.01:
		move_and_slide()
		_update_follow_stuck(delta, true)
		return
	is_walking = true
	_face_direction(Vector3(velocity.x, 0.0, velocity.z))
	_play_walk_animation(horizontal_speed)
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	var step_result := CharacterStepSolver.try_step_up(
		self,
		horizontal_motion,
		FOLLOW_MAX_STEP_HEIGHT,
		true
	)
	last_step_result = step_result.reason
	if not step_result.handled:
		move_and_slide()
	if not step_result.handled and is_on_wall() and velocity.y <= 0.0:
		_try_open_blocking_door()
	_update_follow_stuck(delta, false)


func _try_open_blocking_door() -> void:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider()
		if (
			collider is HingedInteractable
			and (collider as HingedInteractable).display_name.to_lower().contains("door")
			and not (collider as HingedInteractable).is_open
		):
			(collider as HingedInteractable).interact(self)
			return


func _update_follow_stuck(delta: float, no_safe_velocity: bool) -> void:
	var moved := _horizontal_distance_between(global_position, last_follow_position)
	if no_safe_velocity or moved < 0.002:
		follow_stuck_time += delta
	else:
		follow_stuck_time = 0.0
	last_follow_position = global_position
	if follow_stuck_time < FOLLOW_STUCK_REPATH_TIME:
		return
	follow_stuck_time = 0.0
	navigation_repath_time = 0.0


func _follow_target_ground_position() -> Vector3:
	var target_position := follow_target.global_position
	var collision: CollisionShape3D = null
	for child: Node in follow_target.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			collision = child
			break
	if collision == null or collision.shape == null:
		return target_position
	if collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		target_position.y += collision.position.y - capsule.height * 0.5
	elif collision.shape is CylinderShape3D:
		var cylinder := collision.shape as CylinderShape3D
		target_position.y += collision.position.y - cylinder.height * 0.5
	return target_position


func _horizontal_distance_to(point: Vector3) -> float:
	return _horizontal_distance_between(point, global_position)


func _horizontal_distance_between(first: Vector3, second: Vector3) -> float:
	var offset := first - second
	offset.y = 0.0
	return offset.length()


func _setup_foot_planting() -> void:
	if seated or skeleton == null:
		return
	left_upper_leg_bone = skeleton.find_bone(&"LeftUpperLeg")
	left_lower_leg_bone = skeleton.find_bone(&"LeftLowerLeg")
	left_foot_bone = skeleton.find_bone(&"LeftFoot")
	right_upper_leg_bone = skeleton.find_bone(&"RightUpperLeg")
	right_lower_leg_bone = skeleton.find_bone(&"RightLowerLeg")
	right_foot_bone = skeleton.find_bone(&"RightFoot")
	if [
		left_upper_leg_bone,
		left_lower_leg_bone,
		left_foot_bone,
		right_upper_leg_bone,
		right_lower_leg_bone,
		right_foot_bone,
	].has(-1):
		return

	left_foot_target = _make_foot_marker("LeftFootPlantTarget")
	right_foot_target = _make_foot_marker("RightFootPlantTarget")
	left_knee_pole = _make_foot_marker("LeftKneePole")
	right_knee_pole = _make_foot_marker("RightKneePole")
	left_foot_ik = _make_leg_ik(
		"LeftFootPlantIK",
		&"LeftUpperLeg",
		&"LeftLowerLeg",
		&"LeftFoot",
		left_foot_target,
		left_knee_pole
	)
	right_foot_ik = _make_leg_ik(
		"RightFootPlantIK",
		&"RightUpperLeg",
		&"RightLowerLeg",
		&"RightFoot",
		right_foot_target,
		right_knee_pole
	)


func _make_foot_marker(marker_name: String) -> Node3D:
	var marker := Node3D.new()
	marker.name = marker_name
	add_child(marker)
	marker.top_level = true
	return marker


func _make_leg_ik(
	ik_name: String,
	upper_leg_name: StringName,
	lower_leg_name: StringName,
	foot_name: StringName,
	target: Node3D,
	pole: Node3D
) -> TwoBoneIK3D:
	var ik := TwoBoneIK3D.new()
	ik.name = ik_name
	skeleton.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, upper_leg_name)
	ik.set_middle_bone_name(0, lower_leg_name)
	ik.set_end_bone_name(0, foot_name)
	ik.set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_CUSTOM)
	ik.set_pole_direction_vector(0, Vector3.FORWARD)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.influence = 0.0
	return ik


func _update_foot_planting() -> void:
	if left_foot_ik == null or right_foot_ik == null or animation_player == null:
		return
	var walk_is_playing := (
		is_walking
		and not is_talking
		and animation_player.current_animation == WALK_ANIMATION
		and animation_player.current_animation_length > 0.0
	)
	if not walk_is_playing:
		_disable_foot_planting()
		return

	var cycle_phase := fposmod(
		animation_player.current_animation_position
		/ animation_player.current_animation_length,
		1.0
	)
	var left_phase := cycle_phase
	var right_phase := fposmod(cycle_phase - FOOT_STANCE_PORTION, 1.0)
	left_foot_planted = _update_leg_plant(
		left_foot_ik,
		left_foot_target,
		left_knee_pole,
		left_upper_leg_bone,
		left_lower_leg_bone,
		left_foot_bone,
		left_phase,
		left_foot_planted
	)
	right_foot_planted = _update_leg_plant(
		right_foot_ik,
		right_foot_target,
		right_knee_pole,
		right_upper_leg_bone,
		right_lower_leg_bone,
		right_foot_bone,
		right_phase,
		right_foot_planted
	)


func _update_leg_plant(
	ik: TwoBoneIK3D,
	target: Node3D,
	pole: Node3D,
	upper_leg_bone: int,
	lower_leg_bone: int,
	foot_bone: int,
	leg_phase: float,
	was_planted: bool
) -> bool:
	var foot_position := _bone_world_position(foot_bone)
	_update_knee_pole(pole, upper_leg_bone, lower_leg_bone, foot_position)
	var is_planted := leg_phase < FOOT_STANCE_PORTION
	if is_planted and not was_planted:
		target.global_position = _grounded_ankle_position(foot_position)
		target.reset_physics_interpolation()
	elif not is_planted:
		target.global_position = foot_position
	var plant_weight := _foot_plant_weight(leg_phase) if is_planted else 0.0
	ik.influence = plant_weight
	return is_planted


func _update_knee_pole(
	pole: Node3D,
	upper_leg_bone: int,
	lower_leg_bone: int,
	foot_position: Vector3
) -> void:
	var hip_position := _bone_world_position(upper_leg_bone)
	var knee_position := _bone_world_position(lower_leg_bone)
	var hip_to_foot := foot_position - hip_position
	var bend_direction := Vector3.ZERO
	if hip_to_foot.length_squared() > 0.0001:
		var along_leg := hip_to_foot * clampf(
			(knee_position - hip_position).dot(hip_to_foot)
			/ hip_to_foot.length_squared(),
			0.0,
			1.0
		)
		bend_direction = knee_position - (hip_position + along_leg)
	if bend_direction.length_squared() <= 0.0001:
		bend_direction = -global_basis.z
	pole.global_position = knee_position + bend_direction.normalized()
	pole.reset_physics_interpolation()


func _foot_plant_weight(leg_phase: float) -> float:
	var fade_in := smoothstep(0.0, FOOT_PLANT_BLEND_PORTION, leg_phase)
	var fade_out := 1.0 - smoothstep(
		FOOT_STANCE_PORTION - FOOT_PLANT_BLEND_PORTION,
		FOOT_STANCE_PORTION,
		leg_phase
	)
	return fade_in * fade_out


func _bone_world_position(bone: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)


func _grounded_ankle_position(animated_position: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		animated_position + Vector3.UP * 0.3,
		animated_position + Vector3.DOWN * 0.45,
		1,
		[get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty() or result.normal.dot(Vector3.UP) < 0.45:
		return animated_position
	var grounded_position := animated_position
	grounded_position.y = result.position.y + FOOT_GROUND_CLEARANCE
	return grounded_position


func _disable_foot_planting() -> void:
	left_foot_ik.influence = 0.0
	right_foot_ik.influence = 0.0
	left_foot_planted = false
	right_foot_planted = false


func _play_walk_animation(movement_speed: float) -> void:
	_play_animation(
		WALK_ANIMATION,
		clampf(movement_speed / WALK_ANIMATION_REFERENCE_SPEED, 0.4, 1.35)
	)


func _play_animation(animation_name: StringName, playback_speed := 1.0) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.speed_scale = playback_speed
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, 0.2)


func _face_actor(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	var direction := actor.global_position - global_position
	direction.y = 0.0
	_face_direction(direction)


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return
	look_at(global_position + direction, Vector3.UP)


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if not is_talking:
		return
	is_talking = false
	_begin_idle()
