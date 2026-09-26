extends RefCounted
class_name CharacterStepSolver

const MIN_STEP_HEIGHT := 0.05
const TEST_MARGIN := 0.002
const CLEARANCE := 0.005
const SEAM_TOLERANCE := 0.02
const PROBE_INCREMENT := 0.05
const DEFAULT_FORWARD_PROBE := 0.30
const LANDING_MIN_UP_DOT := 0.5


class Result extends RefCounted:
	var handled := false
	var step_height := 0.0
	var lift_distance := 0.0
	var crossed_floor_seam := false
	var reason := "no valid landing"


static func try_step_up(
	body: CharacterBody3D,
	horizontal_motion: Vector3,
	max_step_height: float,
	complete_forward_landing := false
) -> Result:
	var result := Result.new()
	if not body.is_on_floor() or body.velocity.y > 0.0:
		result.reason = "not grounded"
		return result
	if horizontal_motion.length_squared() < 0.000001:
		result.reason = "no horizontal motion"
		return result

	var start_transform := body.global_transform
	var obstacle_collision := KinematicCollision3D.new()
	if not body.test_move(start_transform, horizontal_motion, obstacle_collision):
		result.reason = "no obstacle"
		return result
	if obstacle_collision.get_collision_count() == 0:
		result.reason = "obstacle without contact"
		return result
	var obstacle_normal := obstacle_collision.get_normal(0)
	var obstacle_is_walkable := (
		obstacle_normal.dot(Vector3.UP) >= cos(body.floor_max_angle)
	)

	var maximum_lift := max_step_height + CLEARANCE
	var lift_distances: Array[float] = [
		maximum_lift,
		SEAM_TOLERANCE + CLEARANCE,
	]
	var probe_height := MIN_STEP_HEIGHT
	while probe_height < max_step_height - TEST_MARGIN:
		lift_distances.append(probe_height + CLEARANCE)
		probe_height += PROBE_INCREMENT

	for lift_distance: float in lift_distances:
		var upward := Vector3.UP * lift_distance
		var upward_collision := KinematicCollision3D.new()
		if (
			body.test_move(start_transform, upward, upward_collision)
			and _has_headroom_blocker(body, upward_collision)
		):
			result.reason = "blocked headroom at %.3f" % lift_distance
			continue
		var raised_transform := Transform3D(
			start_transform.basis,
			start_transform.origin + upward
		)

		var forward_collision := KinematicCollision3D.new()
		if body.test_move(raised_transform, horizontal_motion, forward_collision):
			result.reason = "raised path blocked at %.3f" % lift_distance
			var forward_normal := forward_collision.get_normal(0)
			if (
				is_equal_approx(lift_distance, maximum_lift)
				and not obstacle_is_walkable
				and forward_normal.y >= -TEST_MARGIN
			):
				break
			continue

		var down_motion := Vector3.DOWN * (
			lift_distance + body.floor_snap_length
		)
		var motion_direction := horizontal_motion.normalized()
		var probe_distance := horizontal_motion.length()
		var maximum_probe_distance := maxf(
			probe_distance,
			_body_horizontal_radius(body) + CLEARANCE
		) + PROBE_INCREMENT
		while probe_distance <= maximum_probe_distance + TEST_MARGIN:
			var probe_motion := motion_direction * probe_distance
			if body.test_move(raised_transform, probe_motion):
				break
			var raised_probe_transform := Transform3D(
				raised_transform.basis,
				raised_transform.origin + probe_motion
			)
			var down_collision := KinematicCollision3D.new()
			if not body.test_move(
				raised_probe_transform,
				down_motion,
				down_collision
			):
				result.reason = "no landing at %.3f" % lift_distance
				probe_distance += PROBE_INCREMENT
				continue
			if down_collision.get_collision_count() == 0:
				result.reason = "landing without contact"
				probe_distance += PROBE_INCREMENT
				continue

			var landing_normal := down_collision.get_normal(0)
			var landing_up_dot := landing_normal.dot(Vector3.UP)
			var minimum_landing_up_dot := maxf(
				LANDING_MIN_UP_DOT,
				cos(body.floor_max_angle)
			)
			if landing_up_dot < minimum_landing_up_dot:
				result.reason = "landing not walkable normal=%s" % landing_normal
				probe_distance += PROBE_INCREMENT
				continue
			var probed_landing_position := (
				raised_probe_transform.origin + down_collision.get_travel()
			)
			var step_height := probed_landing_position.y - start_transform.origin.y
			var crosses_floor_seam := (
				obstacle_is_walkable
				and absf(step_height) <= SEAM_TOLERANCE
			)
			if (
				(not crosses_floor_seam and step_height < MIN_STEP_HEIGHT)
				or step_height > max_step_height + TEST_MARGIN
			):
				result.reason = "landing height %.3f outside range" % step_height
				probe_distance += PROBE_INCREMENT
				continue

			var landing_position := probed_landing_position
			if not complete_forward_landing:
				landing_position = start_transform.origin + horizontal_motion
				landing_position.y = probed_landing_position.y
			# Slow NPC movement must finish onto the verified support. Stopping at
			# the capsule corner makes it rise, fall, and retry forever.
			body.global_position = landing_position
			body.velocity.y = 0.0
			result.handled = true
			result.step_height = step_height
			result.lift_distance = lift_distance
			result.crossed_floor_seam = crosses_floor_seam
			result.reason = "%s height=%.3f lift=%.3f probe=%.3f" % [
				"crossed floor seam" if crosses_floor_seam else "accepted",
				step_height,
				lift_distance,
				probe_distance,
			]
			return result
	return result


static func _has_headroom_blocker(
	body: CharacterBody3D,
	collision: KinematicCollision3D
) -> bool:
	var minimum_floor_up_dot := cos(body.floor_max_angle)
	for index in collision.get_collision_count():
		# A capsule resting on an imported triangle seam can report its floor as
		# an upward-motion collision. That contact separates the body from the
		# floor; only walls and downward-facing ceiling contacts block the lift.
		if collision.get_normal(index).dot(Vector3.UP) < minimum_floor_up_dot:
			return true
	return false


static func _body_horizontal_radius(body: CharacterBody3D) -> float:
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var shape := (child as CollisionShape3D).shape
		if shape is CapsuleShape3D:
			return (shape as CapsuleShape3D).radius
		if shape is CylinderShape3D:
			return (shape as CylinderShape3D).radius
		if shape is SphereShape3D:
			return (shape as SphereShape3D).radius
		if shape is BoxShape3D:
			var box_size := (shape as BoxShape3D).size
			return minf(box_size.x, box_size.z) * 0.5
	return DEFAULT_FORWARD_PROBE
