extends Item

@export var lit := false

@onready var beam: SpotLight3D = $Beam


func _ready() -> void:
	super()
	beam.visible = lit


func _on_primary_use() -> void:
	lit = not lit
	beam.visible = lit
