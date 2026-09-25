extends MovingInteractable
class_name HingedInteractable

@export_range(20.0, 140.0, 1.0) var open_angle_degrees := 100.0
var hinge_axis := Vector3.UP
var open_direction := 1.0
var choose_direction_from_actor := true
var open_away_from_actor := false


func _prepare_open(actor: Node3D) -> void:
	if not choose_direction_from_actor or actor == null or moving_collision == null:
		return
	var positive_distance := _open_center_for_direction(1.0).distance_squared_to(
		actor.global_position
	)
	var negative_distance := _open_center_for_direction(-1.0).distance_squared_to(
		actor.global_position
	)
	if open_away_from_actor:
		open_direction = 1.0 if positive_distance >= negative_distance else -1.0
	else:
		open_direction = 1.0 if positive_distance <= negative_distance else -1.0


func _set_open_direction(direction: float) -> void:
	open_direction = signf(direction) if not is_zero_approx(direction) else 1.0


func _transform_for_progress(progress: float) -> Transform3D:
	var angle := deg_to_rad(open_angle_degrees) * open_direction * progress
	return closed_transform * Transform3D(Basis(hinge_axis.normalized(), angle), Vector3.ZERO)


func _open_center_for_direction(direction: float) -> Vector3:
	var previous_direction := open_direction
	open_direction = direction
	var open_local := _transform_for_progress(1.0)
	open_direction = previous_direction
	return (
		get_parent_node_3d().global_transform
		* open_local
		* moving_collision.transform
	).origin
