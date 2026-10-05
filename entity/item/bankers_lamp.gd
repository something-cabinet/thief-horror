extends Item

@export var lit := false

@onready var glow: OmniLight3D = $Model/Glow


func _ready() -> void:
	super()
	glow.visible = lit


func _on_primary_use() -> void:
	lit = not lit
	glow.visible = lit
