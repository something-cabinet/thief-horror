extends HeldItem

@export var already_turned_on = false

@onready var beam: SpotLight3D = $Beam


func _on_primary_use() -> void:
	state["lit"] = not state["lit"]
	_on_state_applied()


func _on_state_applied() -> void:
	# State is replaced after _ready, so seed the default here. The dictionary is
	# shared with the pickup/inventory entry, so the default only applies once.
	if not state.has("lit"):
		state["lit"] = already_turned_on
	beam.visible = state["lit"]
