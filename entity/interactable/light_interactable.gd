extends StaticBody3D
class_name LightInteractable

@export var display_name := "Light"

var is_on := true
var is_flickering := false
var flicker_remaining := 0.0
var controlled_light: OmniLight3D
var emissive_materials: Array[StandardMaterial3D] = []
var emission_strengths: Array[float] = []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 4
	add_to_group("interactable")
	set_process(false)


func configure_collision(world_bounds: AABB) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var box := BoxShape3D.new()
	box.size = world_bounds.size + Vector3.ONE * 0.03
	collision.shape = box
	collision.position = to_local(world_bounds.get_center())
	add_child(collision)


func add_emissive_material(material: StandardMaterial3D) -> void:
	emissive_materials.append(material)
	emission_strengths.append(maxf(material.emission_energy_multiplier, 1.0))


func interact(_actor: Node3D) -> bool:
	is_on = not is_on
	is_flickering = true
	flicker_remaining = 0.24
	set_process(true)
	return true


func get_interaction_prompt() -> String:
	if is_flickering:
		return ""
	return "[E] Turn off %s" % display_name if is_on else "[E] Turn on %s" % display_name


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)


func set_on_immediate(enabled: bool) -> void:
	is_on = enabled
	is_flickering = false
	set_process(false)
	_apply_enabled(enabled)


func _process(delta: float) -> void:
	flicker_remaining -= delta
	if flicker_remaining <= 0.0:
		is_flickering = false
		_apply_enabled(is_on)
		set_process(false)
		return
	var flash_on := int(flicker_remaining * 55.0) % 2 == 0
	_apply_enabled(flash_on)


func _apply_enabled(enabled: bool) -> void:
	if controlled_light != null:
		controlled_light.visible = enabled
	for index in emissive_materials.size():
		emissive_materials[index].emission_energy_multiplier = (
			emission_strengths[index] if enabled else 0.0
		)
