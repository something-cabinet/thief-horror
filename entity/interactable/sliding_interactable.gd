extends MovingInteractable
class_name SlidingInteractable

@export_range(0.1, 2.0, 0.05) var travel_distance := 0.45
var slide_axis_parent := Vector3.FORWARD
var slide_axis_world := Vector3.FORWARD
var choose_direction_toward_actor := true
var open_direction := 1.0


func configure_slide_axis(world_axis: Vector3) -> void:
	slide_axis_world = world_axis.normalized()
	var parent_basis := get_parent_node_3d().global_transform.basis
	slide_axis_parent = (parent_basis.inverse() * slide_axis_world).normalized()


func _prepare_open(actor: Node3D) -> void:
	if not choose_direction_toward_actor or actor == null:
		return
	var actor_offset := actor.global_position - global_position
	open_direction = 1.0 if actor_offset.dot(slide_axis_world) >= 0.0 else -1.0


func _set_open_direction(direction: float) -> void:
	open_direction = signf(direction) if not is_zero_approx(direction) else 1.0


func _transform_for_progress(progress: float) -> Transform3D:
	var result := closed_transform
	result.origin += slide_axis_parent * travel_distance * open_direction * progress
	return result
