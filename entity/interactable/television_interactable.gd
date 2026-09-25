extends StaticBody3D
class_name TelevisionInteractable

var is_on := false
var screen_material: ShaderMaterial
var screen_light: SpotLight3D
var screen_light_energy := 0.32
var power_tween: Tween


func _ready() -> void:
	collision_layer = 1
	collision_mask = 4
	add_to_group("interactable")


func configure_collision(world_bounds: AABB) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var box := BoxShape3D.new()
	box.size = world_bounds.size + Vector3.ONE * 0.03
	collision.shape = box
	collision.position = to_local(world_bounds.get_center())
	add_child(collision)


func interact(_actor: Node3D) -> bool:
	is_on = not is_on
	_animate_power(1.0 if is_on else 0.0)
	return true


func get_interaction_prompt() -> String:
	return InputPrompt.format("Turn off television" if is_on else "Turn on television")


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(self, highlighted)


func set_on_immediate(enabled: bool) -> void:
	is_on = enabled
	if power_tween != null and power_tween.is_valid():
		power_tween.kill()
	_set_power_level(1.0 if enabled else 0.0)


func _animate_power(target: float) -> void:
	if screen_material == null:
		return
	if power_tween != null and power_tween.is_valid():
		power_tween.kill()
	var current := float(screen_material.get_shader_parameter("screen_power"))
	power_tween = create_tween()
	power_tween.set_trans(Tween.TRANS_QUAD)
	power_tween.set_ease(Tween.EASE_OUT)
	power_tween.tween_method(
		_set_power_level,
		current,
		target,
		0.62 if target > current else 0.14
	)


func _set_power_level(value: float) -> void:
	if screen_material != null:
		screen_material.set_shader_parameter("screen_power", value)
	if screen_light != null:
		screen_light.visible = value > 0.02
		screen_light.light_energy = screen_light_energy * value
