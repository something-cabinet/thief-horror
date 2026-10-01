extends MovingInteractable
class_name SlidingInteractable

@export_range(0.1, 2.0, 0.05) var travel_distance := 0.45
var slide_axis_parent := Vector3.FORWARD
var slide_axis_world := Vector3.FORWARD
var choose_direction_toward_actor := true
var open_direction := 1.0
var open_top_bounds_local := AABB()


func configure_slide_axis(world_axis: Vector3) -> void:
	slide_axis_world = world_axis.normalized()
	var parent_basis := get_parent_node_3d().global_transform.basis
	slide_axis_parent = (parent_basis.inverse() * slide_axis_world).normalized()


func configure_open_top_collision(world_bounds: AABB) -> void:
	# A single bounds box makes the empty drawer cavity physically solid. Build
	# the five real surfaces so visible contents can be ray-picked from above.
	if moving_collision != null:
		remove_child(moving_collision)
		moving_collision.queue_free()

	var full_size := world_bounds.size
	var depth_axis := (
		Vector3.AXIS_X
		if absf(slide_axis_world.x) >= absf(slide_axis_world.z)
		else Vector3.AXIS_Z
	)
	var lateral_axis := (
		Vector3.AXIS_Z if depth_axis == Vector3.AXIS_X else Vector3.AXIS_X
	)
	var bottom_thickness := clampf(full_size.y * 0.10, 0.025, 0.05)
	var wall_thickness := clampf(
		minf(full_size[depth_axis], full_size[lateral_axis]) * 0.06,
		0.02,
		0.045
	)
	var bounds_center := world_bounds.get_center()
	var local_center := to_local(bounds_center)
	open_top_bounds_local = AABB(local_center - full_size * 0.5, full_size)

	var bottom_size := full_size
	bottom_size.y = bottom_thickness
	var bottom_center := bounds_center
	bottom_center.y = world_bounds.position.y + bottom_thickness * 0.5
	moving_collision = _add_drawer_collision_box(
		"InteractionCollision",
		bottom_center,
		bottom_size
	)

	var vertical_size := maxf(full_size.y - bottom_thickness, 0.02)
	var wall_center_y := world_bounds.position.y + bottom_thickness + vertical_size * 0.5
	var side_size := full_size
	side_size[lateral_axis] = wall_thickness
	side_size.y = vertical_size
	for side_sign in [-1.0, 1.0]:
		var side_center := bounds_center
		side_center.y = wall_center_y
		side_center[lateral_axis] += (
			full_size[lateral_axis] - wall_thickness
		) * 0.5 * side_sign
		_add_drawer_collision_box(
			"DrawerSideCollision",
			side_center,
			side_size
		)

	var end_size := full_size
	end_size[depth_axis] = wall_thickness
	end_size.y = vertical_size
	for end_sign in [-1.0, 1.0]:
		var end_center := bounds_center
		end_center.y = wall_center_y
		end_center[depth_axis] += (
			full_size[depth_axis] - wall_thickness
		) * 0.5 * end_sign
		_add_drawer_collision_box(
			"DrawerEndCollision",
			end_center,
			end_size
		)


func _add_drawer_collision_box(
	shape_name: String,
	world_center: Vector3,
	size: Vector3
) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = shape_name
	var box := BoxShape3D.new()
	box.size = size
	box.margin = 0.003
	collision.shape = box
	collision.position = to_local(world_center)
	add_child(collision)
	return collision


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
