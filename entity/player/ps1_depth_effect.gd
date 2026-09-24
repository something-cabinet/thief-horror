extends MeshInstance3D

const MOTION_RESPONSE := 14.0
const LINEAR_SENSITIVITY := 0.26
const ANGULAR_SENSITIVITY := 0.5

var previous_transform: Transform3D
var motion_amount := 0.0
var effect_material: ShaderMaterial


func _ready() -> void:
	previous_transform = get_parent_node_3d().global_transform
	effect_material = get_active_material(0) as ShaderMaterial


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(effect_material):
		return

	var current_transform := get_parent_node_3d().global_transform
	var linear_speed := current_transform.origin.distance_to(previous_transform.origin) / delta
	var previous_rotation := previous_transform.basis.get_rotation_quaternion()
	var current_rotation := current_transform.basis.get_rotation_quaternion()
	var angular_speed := previous_rotation.angle_to(current_rotation) / delta
	var target_motion: float = clampf(
		linear_speed * LINEAR_SENSITIVITY + angular_speed * ANGULAR_SENSITIVITY,
		0.0,
		1.0
	)
	var response := 1.0 - exp(-MOTION_RESPONSE * delta)
	motion_amount = lerp(motion_amount, target_motion, response)
	effect_material.set_shader_parameter("motion_amount", motion_amount)
	previous_transform = current_transform
