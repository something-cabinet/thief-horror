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


# Unit vector up along the rails. Tilted when the ladder leans.
func get_up() -> Vector3:
	return global_basis.y.normalized()


# Unit vector out of the rail plane toward the side `from` is on.
func get_climb_normal(from: Vector3) -> Vector3:
	var side := 1.0 if to_local(from).x >= climb_collision.position.x else -1.0
	return (global_basis.x * side).normalized()


# Point on the climbing line, on the `normal` side, level with `from` along the
# rails. A leaning ladder brings the top or bottom of an upright body closer to
# the rails, so the line moves out by how far body_half_height leans over.
func get_climb_point(normal: Vector3, from: Vector3, body_half_height: float) -> Vector3:
	var up := get_up()
	var lean := Vector2(up.x, up.z).length()
	var line_origin := climb_collision.global_position + normal * (climb_distance + body_half_height * lean)
	return line_origin + up * (from - line_origin).dot(up)


# Where an upright body stands after climbing over the top onto the `normal` side.
func get_top_exit_point(normal: Vector3) -> Vector3:
	var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
	return _span_point(0.5) + flat_normal * climb_distance


func get_bottom_y() -> float:
	return _span_point(-0.5).y


func get_top_y() -> float:
	return _span_point(0.5).y


func _span_point(half_sign: float) -> Vector3:
	var box := climb_collision.shape as BoxShape3D
	return to_global(climb_collision.position + Vector3(0.0, box.size.y * half_sign, 0.0))
