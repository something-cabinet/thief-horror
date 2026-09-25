extends StaticBody3D
class_name TrapDoor

@export var display_name := "Trap Door"
## Index into GameManager.level_list of the level this trap door leads to.
@export var target_level_index := 1

var is_used := false


func _ready() -> void:
	add_to_group("interactable")


func get_interaction_prompt() -> String:
	return InputPrompt.format("Enter %s" % display_name)


func interact(_player: Node) -> void:
	return
	# change_level is deferred, so guard against a second press before the scene swaps.
	if is_used:
		return
	if target_level_index < 0 or target_level_index >= GameManager.level_list.size():
		push_error("%s: target_level_index %d is not in GameManager.level_list" % [name, target_level_index])
		return
	is_used = true
	GameManager.change_level(target_level_index)


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)
