extends HingedInteractable
class_name InteractableDoor


func _init() -> void:
	display_name = "Front door"
	open_angle_degrees = 100.0
	movement_speed = 1.5
	open_away_from_actor = true
	closing_safety_samples = 9


func configure_collision(closed_world_bounds: AABB, _hinge_world_position: Vector3) -> void:
	configure_bounds_collision(closed_world_bounds)
