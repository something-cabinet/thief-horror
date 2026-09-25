extends AnimatableBody3D
class_name MovingInteractable

@export var display_name := "Panel"
@export_range(0.25, 8.0, 0.05) var movement_speed := 2.5

var is_open := false
var is_moving := false
var movement_progress := 0.0
var target_progress := 0.0
var blocked_message_until_msec := 0
var moving_collision: CollisionShape3D
var closed_transform: Transform3D
var closing_safety_samples := 1
var interaction_normal_local := Vector3.ZERO


func _ready() -> void:
	closed_transform = transform
	collision_layer = 1
	collision_mask = 4
	add_to_group("interactable")
	sync_to_physics = false
	set_physics_process(false)


func configure_bounds_collision(world_bounds: AABB) -> void:
	closed_transform = transform
	moving_collision = CollisionShape3D.new()
	moving_collision.name = "InteractionCollision"
	var box := BoxShape3D.new()
	box.size = world_bounds.size + Vector3.ONE * 0.02
	moving_collision.shape = box
	moving_collision.position = to_local(world_bounds.get_center())
	add_child(moving_collision)


func interact(actor: Node3D) -> bool:
	if is_moving:
		if target_progress > 0.5:
			if _closing_path_is_blocked():
				blocked_message_until_msec = Time.get_ticks_msec() + 1200
				return false
			is_open = false
			target_progress = 0.0
		else:
			is_open = true
			target_progress = 1.0
		return true
	if is_open:
		if _closing_path_is_blocked():
			blocked_message_until_msec = Time.get_ticks_msec() + 1200
			return false
		is_open = false
		target_progress = 0.0
	else:
		_prepare_open(actor)
		is_open = true
		target_progress = 1.0
	is_moving = true
	set_physics_process(true)
	return true


func get_interaction_prompt() -> String:
	if Time.get_ticks_msec() < blocked_message_until_msec:
		return "Move clear of %s" % display_name
	return "[E] Close %s" % display_name if is_open else "[E] Open %s" % display_name


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)


func restrict_interaction_to_side(world_normal: Vector3) -> void:
	interaction_normal_local = (
		global_transform.basis.inverse() * world_normal.normalized()
	).normalized()


func can_interact_from(world_position: Vector3) -> bool:
	if interaction_normal_local.is_zero_approx() or moving_collision == null:
		return true
	# The side restriction only prevents selecting a closed panel through the
	# van. Once the door has moved, either visible face must remain usable so it
	# can always be closed again.
	if is_moving or movement_progress > 0.05:
		return true
	var interaction_normal_world := (
		global_transform.basis * interaction_normal_local
	).normalized()
	var collision_center := global_transform * moving_collision.position
	return (world_position - collision_center).dot(interaction_normal_world) > 0.05


func set_open_immediate(open: bool, direction := 0.0) -> void:
	if not is_zero_approx(direction):
		_set_open_direction(direction)
	is_open = open
	movement_progress = 1.0 if open else 0.0
	target_progress = movement_progress
	transform = _transform_for_progress(movement_progress)
	is_moving = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	movement_progress = move_toward(
		movement_progress,
		target_progress,
		movement_speed * delta
	)
	transform = _transform_for_progress(movement_progress)
	if is_equal_approx(movement_progress, target_progress):
		movement_progress = target_progress
		transform = _transform_for_progress(movement_progress)
		is_moving = false
		set_physics_process(false)


func _prepare_open(_actor: Node3D) -> void:
	pass


func _set_open_direction(_direction: float) -> void:
	pass


func _transform_for_progress(_progress: float) -> Transform3D:
	return closed_transform


func _closing_path_is_blocked() -> bool:
	if moving_collision == null or moving_collision.shape == null or not is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = moving_collision.shape
	query.collision_mask = 4
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for step in closing_safety_samples:
		var weight := (
			1.0
			if closing_safety_samples == 1
			else float(step) / float(closing_safety_samples - 1)
		)
		var sample_progress := lerpf(movement_progress, 0.0, weight)
		var sample_local := _transform_for_progress(sample_progress)
		query.transform = (
			get_parent_node_3d().global_transform
			* sample_local
			* moving_collision.transform
		)
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return true
	return false
