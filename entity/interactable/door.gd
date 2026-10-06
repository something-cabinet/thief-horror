extends HingedInteractable

# The scene root sits on the hinge edge, so rotating it swings the door
# around the hinge. The collision child is authored in Door.tscn.
@onready var door_collision: CollisionShape3D = $DoorCollision


func _init() -> void:
	display_name = "Door"
	open_angle_degrees = 85.0
	movement_speed = 1.5
	open_away_from_actor = true
	closing_safety_samples = 9


func _ready() -> void:
	super()
	moving_collision = door_collision
