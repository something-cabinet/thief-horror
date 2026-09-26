extends RigidBody3D
class_name PickupItem

const NOTEBOOK_COLLISION_THICKNESS := 0.15
const DEFAULT_MIN_COLLISION_SIZE := 0.025
const FLOOR_GUARD_DISTANCE := 0.45
const FLOOR_GUARD_SAMPLE_OFFSET := 0.12
const SUPPORT_CLEARANCE := 0.003

@export var item_id: StringName
@export var display_name := "Item"
@export var item_kind: StringName = &"item"
@export var gun_slot := -1
@export var model_scene: PackedScene
@export var icon: Texture2D
@export_range(0.2, 1.5, 0.05) var display_size := 0.55
@export_range(0.05, 10.0, 0.05) var item_mass := 0.5
@export var fit_size_limit := Vector3.ZERO

@onready var model_anchor: Node3D = $ModelAnchor
@onready var temporary_collider: CollisionShape3D = $TemporaryCollider # To avoid Godot warning

var model_instance: Node3D
var normalized_bounds := AABB()
var actual_normalized_size := Vector3.ZERO
var previous_physics_transform := Transform3D.IDENTITY
var has_previous_physics_transform := false
var follows_parent_support := false
var support_local_transform := Transform3D.IDENTITY


func _ready() -> void:
	temporary_collider.queue_free()
	collision_layer = 8
	collision_mask = 9
	mass = item_mass
	continuous_cd = true
	linear_damp = 0.65
	angular_damp = 0.9
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.8
	physics_material.bounce = 0.02
	physics_material_override = physics_material
	add_to_group("collectible")
	add_to_group("interactable")
	if model_scene == null:
		return
	model_instance = model_scene.instantiate() as Node3D
	model_anchor.add_child(model_instance)
	model_instance.process_mode = Node.PROCESS_MODE_DISABLED
	_prepare_model()
	_fit_model_to_limit()
	_create_compound_collision()


func place_on_local_support(
	size_limit: Vector3,
	random: RandomNumberGenerator
) -> void:
	var yaw := rotation.y
	var footprint_x := (
		absf(cos(yaw)) * actual_normalized_size.x
		+ absf(sin(yaw)) * actual_normalized_size.z
	)
	var footprint_z := (
		absf(sin(yaw)) * actual_normalized_size.x
		+ absf(cos(yaw)) * actual_normalized_size.z
	)
	var x_room := maxf(0.0, size_limit.x - footprint_x) * 0.42
	var z_room := maxf(0.0, size_limit.z - footprint_z) * 0.42
	position = Vector3(
		random.randf_range(-x_room, x_room),
		actual_normalized_size.y * 0.5 + SUPPORT_CLEARANCE,
		random.randf_range(-z_room, z_room)
	)


func attach_to_parent_support() -> void:
	var parent := get_parent_node_3d()
	if parent == null:
		return
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	support_local_transform = transform
	follows_parent_support = true
	set_physics_process(true)
	global_transform = parent.global_transform * support_local_transform


func _physics_process(_delta: float) -> void:
	if follows_parent_support:
		var parent := get_parent_node_3d()
		if parent != null:
			global_transform = parent.global_transform * support_local_transform
		return
	var current_transform := global_transform
	if not has_previous_physics_transform:
		previous_physics_transform = current_transform
		has_previous_physics_transform = true
		return
	if current_transform.origin.y < previous_physics_transform.origin.y:
		var floor_hit := _find_crossed_floor(
			previous_physics_transform.origin,
			current_transform.origin
		)
		if not floor_hit.is_empty():
			var floor_normal: Vector3 = floor_hit.normal
			var support_extent := _support_extent_along(floor_normal, current_transform.basis)
			var floor_position: Vector3 = floor_hit.position
			var floor_distance := (current_transform.origin - floor_position).dot(floor_normal)
			var penetration := support_extent - floor_distance + 0.003
			current_transform.origin += floor_normal * penetration
			global_transform = current_transform
			var inward_speed := linear_velocity.dot(floor_normal)
			if inward_speed < 0.0:
				linear_velocity -= floor_normal * inward_speed
			linear_velocity *= 0.75
			angular_velocity *= 0.8
	previous_physics_transform = global_transform


func _find_crossed_floor(previous_position: Vector3, current_position: Vector3) -> Dictionary:
	var highest_hit: Dictionary = {}
	var sample_offsets := [
		Vector2.ZERO,
		Vector2(FLOOR_GUARD_SAMPLE_OFFSET, 0.0),
		Vector2(-FLOOR_GUARD_SAMPLE_OFFSET, 0.0),
		Vector2(0.0, FLOOR_GUARD_SAMPLE_OFFSET),
		Vector2(0.0, -FLOOR_GUARD_SAMPLE_OFFSET),
		Vector2(FLOOR_GUARD_SAMPLE_OFFSET, FLOOR_GUARD_SAMPLE_OFFSET),
		Vector2(FLOOR_GUARD_SAMPLE_OFFSET, -FLOOR_GUARD_SAMPLE_OFFSET),
		Vector2(-FLOOR_GUARD_SAMPLE_OFFSET, FLOOR_GUARD_SAMPLE_OFFSET),
		Vector2(-FLOOR_GUARD_SAMPLE_OFFSET, -FLOOR_GUARD_SAMPLE_OFFSET),
	]
	for offset: Vector2 in sample_offsets:
		var ray_start := Vector3(
			current_position.x + offset.x,
			previous_position.y + FLOOR_GUARD_DISTANCE,
			current_position.z + offset.y
		)
		var ray_end := Vector3(
			current_position.x + offset.x,
			current_position.y - FLOOR_GUARD_DISTANCE,
			current_position.z + offset.y
		)
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_normal: Vector3 = hit.normal
		var hit_position: Vector3 = hit.position
		if hit_normal.dot(Vector3.UP) < 0.55:
			continue
		if previous_position.y + 0.02 < hit_position.y:
			continue
		if current_position.y >= hit_position.y - 0.003:
			continue
		if highest_hit.is_empty() or hit_position.y > (highest_hit.position as Vector3).y:
			highest_hit = hit
	return highest_hit


func _support_extent_along(normal: Vector3, body_basis: Basis) -> float:
	var half_size := normalized_bounds.size * 0.5
	return (
		absf(normal.dot(body_basis.x)) * half_size.x
		+ absf(normal.dot(body_basis.y)) * half_size.y
		+ absf(normal.dot(body_basis.z)) * half_size.z
	)


func collect(player) -> bool:
	if not player.add_inventory_item(
		item_id,
		display_name,
		model_scene,
		icon,
		display_size,
		item_mass,
		item_kind,
		gun_slot
	):
		return false
	queue_free()
	return true


func interact(player) -> bool:
	return collect(player)


func get_interaction_prompt() -> String:
	return "[E] Collect %s" % display_name


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(model_instance, highlighted)


func _prepare_model() -> void:
	var bounds := _calculate_bounds(model_instance)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_side <= 0.0001:
		return
	var scale_factor := display_size / longest_side
	model_instance.scale = Vector3.ONE * scale_factor
	model_instance.position = - bounds.get_center() * scale_factor
	actual_normalized_size = bounds.size * scale_factor
	var minimum_collision_size := (
		NOTEBOOK_COLLISION_THICKNESS
		if item_id == &"notebook"
		else DEFAULT_MIN_COLLISION_SIZE
	)
	if item_id == &"notebook" and actual_normalized_size.y < minimum_collision_size:
		# Keep the visible cover flush with the floor while its slightly thicker
		# hidden collider bridges seams in the imported house floor.
		model_instance.position.y -= (
			minimum_collision_size - actual_normalized_size.y
		) * 0.5
	normalized_bounds = AABB(
		- bounds.size * scale_factor * 0.5,
		Vector3(
			maxf(bounds.size.x * scale_factor, minimum_collision_size),
			maxf(bounds.size.y * scale_factor, minimum_collision_size),
			maxf(bounds.size.z * scale_factor, minimum_collision_size)
		)
	)


func _fit_model_to_limit() -> void:
	if fit_size_limit.x <= 0.0 or fit_size_limit.y <= 0.0 or fit_size_limit.z <= 0.0:
		return
	var yaw := rotation.y
	var footprint_x := (
		absf(cos(yaw)) * actual_normalized_size.x
		+ absf(sin(yaw)) * actual_normalized_size.z
	)
	var footprint_z := (
		absf(sin(yaw)) * actual_normalized_size.x
		+ absf(cos(yaw)) * actual_normalized_size.z
	)
	var fit_scale := minf(
		fit_size_limit.x / maxf(footprint_x, 0.001),
		minf(
			fit_size_limit.y / maxf(actual_normalized_size.y, 0.001),
			fit_size_limit.z / maxf(footprint_z, 0.001)
		)
	) * 0.76
	if fit_scale >= 1.0:
		return
	display_size *= fit_scale
	model_instance.scale *= fit_scale
	model_instance.position *= fit_scale
	actual_normalized_size *= fit_scale
	normalized_bounds.position *= fit_scale
	normalized_bounds.size *= fit_scale


func _create_compound_collision() -> void:
	if not is_inside_tree():
		return
	# Imported per-part convex hulls have uneven invisible protrusions which let
	# objects balance upright. One fitted box gives every collectible predictable
	# contact surfaces and prevents thin pieces from tunneling through the floor.
	_add_fallback_collision()


func _add_fallback_collision() -> void:
	var fallback_shape := BoxShape3D.new()
	fallback_shape.size = normalized_bounds.size
	fallback_shape.margin = 0.005
	var fallback_collision := CollisionShape3D.new()
	fallback_collision.shape = fallback_shape
	add_child(fallback_collision)


func _calculate_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var has_point := false
	var inverse_root := root.global_transform.affine_inverse()
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_transform := inverse_root * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.mesh.get_aabb()
		var bounds_end := mesh_bounds.position + mesh_bounds.size
		for x in [mesh_bounds.position.x, bounds_end.x]:
			for y in [mesh_bounds.position.y, bounds_end.y]:
				for z in [mesh_bounds.position.z, bounds_end.z]:
					var point := local_transform * Vector3(x, y, z)
					if not has_point:
						result = AABB(point, Vector3.ZERO)
						has_point = true
					else:
						result = result.expand(point)
	return result
