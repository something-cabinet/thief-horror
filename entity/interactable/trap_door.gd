extends StaticBody3D
class_name TrapDoor

@export var display_name := "Trap Door"
## Level this trap door leads to. Stored as a path and loaded on use, because
## levels that link to each other would otherwise load each other in a cycle.
@export_file("*.tscn") var target_level_path := ""

var is_used := false


func _ready() -> void:
	add_to_group("interactable")


func get_interaction_prompt() -> String:
	return InputPrompt.format("Enter %s" % display_name)


func interact(_player: Node) -> void:
	# change_level is deferred, so guard against a second press before the scene swaps.
	if is_used:
		return
	var target_level := load(target_level_path) as PackedScene if not target_level_path.is_empty() else null
	if target_level == null:
		push_error("%s: target_level_path \"%s\" is not a scene" % [name, target_level_path])
		return
	is_used = true
	GameManager.change_level(target_level)


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)
