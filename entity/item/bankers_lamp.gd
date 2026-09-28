extends HeldItem

@onready var glow: OmniLight3D = $Glow


func _on_primary_use() -> void:
	state["lit"] = not state.get("lit", false)
	_on_state_applied()


func _on_state_applied() -> void:
	glow.visible = state.get("lit", false)
