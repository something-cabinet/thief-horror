extends StaticBody3D
class_name Ladder

# A climbable ladder. Interacting attaches the player (see Player.grab_ladder);
# the climbable span and rail plane come from ClimbCollision, so resizing that
# box in the editor also changes where the player can climb.

@export var display_name := "Ladder"
@export var climb_speed := 1.6
## Horizontal distance from the rail plane to the player's center while climbing.
@export var climb_distance := 0.32

@onready var climb_collision: CollisionShape3D = $ClimbCollision


func _ready() -> void:
	add_to_group("interactable")


func interact(actor: Node3D) -> bool:
	var player := actor as Player
	if player == null:
		return false
	if player.current_ladder == self:
		player.release_ladder()
	else:
		player.grab_ladder(self)
	return true


func get_interaction_prompt() -> String:
	var player := GameManager.player as Player
	if player != null and player.current_ladder == self:
		return InputPrompt.format("Let go of %s" % display_name)
	return InputPrompt.format("Climb %s" % display_name)


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)


# Horizontal unit vector pointing out of the rail plane toward the side `from` is on.
func get_climb_normal(from: Vector3) -> Vector3:
	var side := 1.0 if to_local(from).x >= climb_collision.position.x else -1.0
	var normal := global_basis * Vector3(side, 0.0, 0.0)
	normal.y = 0.0
	return normal.normalized()


# Where the player's center sits horizontally while climbing on the `normal` side.
func get_climb_point(normal: Vector3) -> Vector3:
	return climb_collision.global_position + normal * climb_distance


func get_bottom_y() -> float:
	return _span_y(-0.5)


func get_top_y() -> float:
	return _span_y(0.5)


func _span_y(half_sign: float) -> float:
	var box := climb_collision.shape as BoxShape3D
	var local_point := climb_collision.position + Vector3(0.0, box.size.y * half_sign, 0.0)
	return to_global(local_point).y
