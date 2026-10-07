extends RigidBody3D
class_name Item

## An item that lies in the world, sits in the inventory and is held in the
## player's hand. The same node is used in all three places, so per-item state
## (a lamp being lit, a gun's timers) is just member variables.
##
## Make a new item by inheriting Item.tscn: put the visuals under Model and
## resize the Collision shape (a 1 m cube by default) to fit them.

const NOTEBOOK_COLLISION_THICKNESS := 0.15
const DEFAULT_MIN_COLLISION_SIZE := 0.025
const FLOOR_GUARD_DISTANCE := 0.45
const FLOOR_GUARD_SAMPLE_OFFSET := 0.12
const SUPPORT_CLEARANCE := 0.003

@export var item_id: StringName
@export var display_name := "Item"
@export var icon: Texture2D
@export_group("Hand")
## Scale and rotate the item into the generic hand pose. Turn off for items
## with an authored first-person pose, such as guns.
@export var fit_to_hand := true
## Transform relative to the player's HeldItemPivot, used when fit_to_hand is off.
@export var hand_transform := Transform3D.IDENTITY

@onready var model: Node3D = $Model

## The player holding this item, or null while it lies in the world.
var player: Player
var use_input_armed := false
## Size of the item's collision, in the item's local space.
var item_size := Vector3.ZERO
var previous_physics_transform := Transform3D.IDENTITY
var has_previous_physics_transform := false
var follows_parent_support := false
var support_local_transform := Transform3D.IDENTITY
var world_collision_layer := 0
var world_collision_mask := 0


func _ready() -> void:
	add_to_group("collectible")
	add_to_group("interactable")
	world_collision_layer = collision_layer
	world_collision_mask = collision_mask
	if item_size == Vector3.ZERO:
		item_size = _calculate_collision_bounds().size


## Normalizes Model so its longest side is longest_side, shrinks it further to
## fit size_limit, and replaces the collision with a box around it. Used for
## items built at runtime from a bare model, such as house loot.
func fit_model(longest_side: float, size_limit := Vector3.ZERO) -> void:
	var bounds := calculate_mesh_bounds(model, model)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.0001:
		return
	var scale_factor := longest_side / longest
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor
	var visible_size := bounds.size * scale_factor
	var minimum_collision_size := (
		NOTEBOOK_COLLISION_THICKNESS
		if item_id == &"notebook"
		else DEFAULT_MIN_COLLISION_SIZE
	)
	if item_id == &"notebook" and visible_size.y < minimum_collision_size:
		# Keep the visible cover flush with the floor while its slightly thicker
		# hidden collider bridges seams in the imported house floor.
		model.position.y -= (minimum_collision_size - visible_size.y) * 0.5
	var collision_size := Vector3(
		maxf(visible_size.x, minimum_collision_size),
		maxf(visible_size.y, minimum_collision_size),
		maxf(visible_size.z, minimum_collision_size)
	)
	if size_limit.x > 0.0 and size_limit.y > 0.0 and size_limit.z > 0.0:
		var footprint := _footprint(visible_size)
		var fit_scale := minf(
			size_limit.x / maxf(footprint.x, 0.001),
			minf(
				size_limit.y / maxf(visible_size.y, 0.001),
				size_limit.z / maxf(footprint.y, 0.001)
			)
		) * 0.76
		if fit_scale < 1.0:
			model.scale *= fit_scale
			model.position *= fit_scale
			visible_size *= fit_scale
			collision_size *= fit_scale
	item_size = visible_size
	# One fitted box gives every collectible predictable contact surfaces and
	# prevents thin pieces from tunneling through the floor.
	var shape := BoxShape3D.new()
	shape.size = collision_size
	shape.margin = 0.005
	var collision := get_node("Collision") as CollisionShape3D
	collision.transform = Transform3D.IDENTITY
	collision.shape = shape


func place_on_local_support(
	size_limit: Vector3,
	random: RandomNumberGenerator
) -> void:
	var footprint := _footprint(item_size)
	var x_room := maxf(0.0, size_limit.x - footprint.x) * 0.42
	var z_room := maxf(0.0, size_limit.z - footprint.y) * 0.42
	position = Vector3(
		random.randf_range(-x_room, x_room),
		item_size.y * 0.5 + SUPPORT_CLEARANCE,
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


## Called by the player each time this item is put into its hand.
func equip(holder: Player) -> void:
	player = holder
	use_input_armed = false
	follows_parent_support = false
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 0
	collision_mask = 0
	# A body in the physics space keeps writing its world transform back to the
	# node, which pins it in place instead of following the camera. Re-entering
	# the world on release puts it back into the space.
	PhysicsServer3D.body_set_space(get_rid(), RID())
	set_highlighted(false)
	_on_equipped()


func _notification(what: int) -> void:
	# Re-enabling a disabled body (e.g. the title-screen preview player being
	# switched back on) puts it back into the physics space, which would pin a
	# held item in the world again. See equip().
	if what == NOTIFICATION_ENABLED and player != null:
		PhysicsServer3D.body_set_space(get_rid(), RID())


## Called by the player when this item is thrown back into the world, after it
## is added to the level. The caller sets the transform and velocity afterwards.
func release() -> void:
	player = null
	collision_layer = world_collision_layer
	collision_mask = world_collision_mask
	freeze = false
	has_previous_physics_transform = false
	# The hand pose may have scaled the body; physics bodies must stay unscaled.
	transform.basis = transform.basis.orthonormalized()


func _process(delta: float) -> void:
	if player == null:
		return
	if not player.can_use_held_item():
		use_input_armed = false
		return
	# The click that selected this item or closed a dialogue must not also use it.
	if not use_input_armed:
		use_input_armed = (
			not Input.is_action_pressed("primary_attack")
			and not Input.is_action_pressed("secondary_attack")
		)
		return
	_process_use_input(delta)


## Override for continuous input such as hold-to-fire. By default each click
## calls the matching use callback once.
func _process_use_input(_delta: float) -> void:
	if Input.is_action_just_pressed("primary_attack"):
		_on_primary_use()
	if Input.is_action_just_pressed("secondary_attack"):
		_on_secondary_use()


func _on_primary_use() -> void:
	pass


func _on_secondary_use() -> void:
	pass


func _on_equipped() -> void:
	pass


func _physics_process(_delta: float) -> void:
	if player != null:
		return
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
	var half_size := item_size * 0.5
	return (
		absf(normal.dot(body_basis.x)) * half_size.x
		+ absf(normal.dot(body_basis.y)) * half_size.y
		+ absf(normal.dot(body_basis.z)) * half_size.z
	)


func interact(holder: Player) -> bool:
	return holder.add_inventory_item(self)


func get_interaction_prompt() -> String:
	return InputPrompt.format("Collect %s" % display_name)


func set_highlighted(highlighted: bool) -> void:
	InteractableVisual.set_highlighted(model, highlighted)


func _footprint(size: Vector3) -> Vector2:
	var yaw := rotation.y
	return Vector2(
		absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z,
		absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z
	)


func _calculate_collision_bounds() -> AABB:
	var result := AABB()
	var has_shape := false
	for child: Node in get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var shape_bounds := collision.transform * collision.shape.get_debug_mesh().get_aabb()
		result = shape_bounds if not has_shape else result.merge(shape_bounds)
		has_shape = true
	return result


## Bounds of every mesh under root, in relative_to's local space. Works outside
## the scene tree because it walks local transforms instead of global ones.
static func calculate_mesh_bounds(root: Node3D, relative_to: Node3D) -> AABB:
	var result := AABB()
	var has_point := false
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for child: Node in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_transform := Transform3D.IDENTITY
		var node: Node = mesh_instance
		while node != relative_to and node != null:
			if node is Node3D:
				local_transform = (node as Node3D).transform * local_transform
			node = node.get_parent()
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
