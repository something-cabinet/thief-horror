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
const FOLLOW_MAX_STEP_HEIGHT := 0.35
const FOLLOW_STEP_INCREMENT := 0.05

@export var display_name := "Grandma"
@export var model_scene: PackedScene
@export var animation_library: AnimationLibrary
@export var greeting_dialogue: DialogueResource
@export var dialogue_title := "start"
@export var seated := false
@export var follow_target_path: NodePath
@export var follow_distance := 1.5
@export var follow_speed := 1.7
@export var catch_up_distance := 4.0
@export var catch_up_speed := 2.5
@export var follow_waypoint_spacing := 0.35
@export var follow_waypoint_reach_distance := 0.5
@export var random_seed_offset := 0
@export var walk_speed := 0.55
@export var wander_radius := 2.0
@export var minimum_idle_time := 1.5
@export var maximum_idle_time := 4.0
@export var minimum_walk_time := 1.5
@export var maximum_walk_time := 3.5

@onready var model_anchor: Node3D = $ModelAnchor

var model_instance: Node3D
var animation_player: AnimationPlayer
var random := RandomNumberGenerator.new()
var spawn_position := Vector3.ZERO
var wander_direction := Vector3.ZERO
var state_time_remaining := 0.0
var is_walking := false
var is_talking := false
var follow_target: Node3D
var follow_waypoints: Array[Vector3] = []
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 1
	collision_mask = 5
	add_to_group("interactable")
	spawn_position = global_position
	random.seed = hash(global_position) + random_seed_offset
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path) as Node3D
		if follow_target != null:
			follow_waypoints.append(follow_target.global_position)

	if model_scene != null:
		model_instance = model_scene.instantiate() as Node3D
		model_anchor.add_child(model_instance)
		_cache_animation_player()
		_attach_animation_library()
		_configure_animation_loops()

	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	if dialogue_manager != null:
		dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)

	_begin_idle()


func _physics_process(delta: float) -> void:
	if seated:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if is_talking:
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


func _cache_animation_player() -> void:
	var players := model_instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	animation_player = players[0] as AnimationPlayer


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
	_play_animation(WALK_ANIMATION)


func _update_following(delta: float) -> void:
	_record_follow_waypoint()
	while follow_waypoints.size() > 1 and _horizontal_distance_to(
		follow_waypoints[0]
	) <= follow_waypoint_reach_distance:
		follow_waypoints.pop_front()

	var destination := follow_waypoints[0]
	var target_distance := _horizontal_distance_to(follow_target.global_position)
	if follow_waypoints.size() == 1 and target_distance <= follow_distance:
		velocity.x = move_toward(velocity.x, 0.0, follow_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, follow_speed * 5.0 * delta)
		if is_walking:
			_begin_idle()
		move_and_slide()
		return

	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	var speed := catch_up_speed if target_distance >= catch_up_distance else follow_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	is_walking = true
	_face_direction(direction)
	_play_animation(WALK_ANIMATION)
	var start_transform := global_transform
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	if is_on_wall() and velocity.y <= 0.0:
		_try_follow_step(start_transform, horizontal_motion)


func _record_follow_waypoint() -> void:
	var target_position := follow_target.global_position
	if follow_waypoints.is_empty():
		follow_waypoints.append(target_position)
		return
	if follow_waypoints[-1].distance_to(target_position) >= follow_waypoint_spacing:
		follow_waypoints.append(target_position)


func _horizontal_distance_to(point: Vector3) -> float:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length()


func _try_follow_step(start_transform: Transform3D, horizontal_motion: Vector3) -> bool:
	var step_height := FOLLOW_STEP_INCREMENT
	while step_height <= FOLLOW_MAX_STEP_HEIGHT + 0.001:
		var upward := Vector3.UP * step_height
		if test_move(start_transform, upward):
			step_height += FOLLOW_STEP_INCREMENT
			continue
		var raised_transform := Transform3D(
			start_transform.basis,
			start_transform.origin + upward
		)
		if test_move(raised_transform, horizontal_motion):
			step_height += FOLLOW_STEP_INCREMENT
			continue
		var forward_transform := Transform3D(
			raised_transform.basis,
			raised_transform.origin + horizontal_motion
		)
		if not test_move(
			forward_transform,
			Vector3.DOWN * (step_height + FOLLOW_STEP_INCREMENT)
		):
			step_height += FOLLOW_STEP_INCREMENT
			continue
		global_transform = raised_transform
		move_and_collide(horizontal_motion)
		move_and_collide(Vector3.DOWN * (step_height + FOLLOW_STEP_INCREMENT))
		velocity.y = 0.0
		return true
	return false


func _play_animation(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
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
