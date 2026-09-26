extends SceneTree

const HOUSE_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const PICKUP_ITEM_SCENE := preload("res://entity/item/PickupItem.tscn")
const PHOTO_FRAME_SCENE := preload("res://asset/model/loot_review/photo_frame_mp_1.glb")
const EXPECTED_COUNTS := {
	"drawer": 18,
	"fridge": 4,
	"shelf": 156,
	"table": 17,
}
const REQUIRED_ITEMS_PER_SOCKET := {
	"drawer": 1,
	"cabinet": 2,
	"wardrobe": 4,
	"fridge": 2,
}
const RUNTIME_COUNT_LIMITS := {
	"shelf": Vector2i(20, 20),
	"table": Vector2i(10, 17),
}


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var failures: Array[String] = []
	_verify_catalog(failures)
	ProjectSettings.set_setting("thief_horror/runtime_loot_seed", 1337)
	var house := HOUSE_SCENE.instantiate()
	root.add_child(house)
	await process_frame
	await physics_frame
	_verify_refrigerator_collision(house, failures)
	await process_frame
	await physics_frame

	var counts := {}
	var positions_by_source := {}
	var covered_cabinet_doors := {}
	for child: Node in get_nodes_in_group("loot_socket"):
		var socket := child as Marker3D
		var type := String(socket.get("socket_type"))
		counts[type] = int(counts.get(type, 0)) + 1
		var size_limit: Vector3 = socket.get("max_item_size")
		if size_limit.x <= 0.0 or size_limit.y <= 0.0 or size_limit.z <= 0.0:
			failures.append("%s has a non-positive size limit" % socket.get_path())

		var source_path: NodePath = socket.get("source_node")
		var source := root.get_node_or_null(source_path)
		if source == null:
			failures.append("%s has missing source %s" % [socket.get_path(), source_path])
			continue
		if type == "fridge":
			if source.name != &"Refrigerador":
				failures.append("%s is not supported by the refrigerator body" % socket.get_path())
			if socket.get_parent() is MovingInteractable:
				failures.append("%s is still attached to a refrigerator door" % socket.get_path())
		var source_key := String(source_path)
		if type in ["cabinet", "wardrobe"]:
			for support_path: NodePath in (socket as LootSocket).support_nodes:
				var support := root.get_node_or_null(support_path) as HingedInteractable
				if support != null and support.display_name == "cabinet door":
					covered_cabinet_doors[support.get_instance_id()] = int(
						covered_cabinet_doors.get(support.get_instance_id(), 0)
					) + 1
		var quantized := Vector3i(
			roundi(socket.global_position.x * 100.0),
			roundi(socket.global_position.y * 100.0),
			roundi(socket.global_position.z * 100.0)
		)
		if not positions_by_source.has(source_key):
			positions_by_source[source_key] = {}
		if positions_by_source[source_key].has(quantized):
			failures.append("%s duplicates another socket on %s" % [socket.get_path(), source_path])
		positions_by_source[source_key][quantized] = true

		if source is MeshInstance3D:
			var mesh := source as MeshInstance3D
			var bounds := (mesh.global_transform * mesh.get_aabb()).grow(0.09)
			if not bounds.has_point(socket.global_position):
				failures.append("%s lies outside %s" % [socket.get_path(), source_path])
		elif source is SlidingInteractable:
			_verify_drawer_socket(socket, source as SlidingInteractable, failures)
		elif source is HingedInteractable:
			_verify_hinged_socket(socket, source as HingedInteractable, failures)

	for type: String in EXPECTED_COUNTS:
		var actual := int(counts.get(type, 0))
		var expected := int(EXPECTED_COUNTS[type])
		if actual != expected:
			failures.append("expected %d %s sockets, found %d" % [expected, type, actual])
	for child: Node in house.find_children("*", "HingedInteractable", true, false):
		var door := child as HingedInteractable
		if door.display_name != "cabinet door":
			continue
		var coverage := int(covered_cabinet_doors.get(door.get_instance_id(), 0))
		if coverage != 1:
			failures.append("%s has %d populated storage sockets" % [door.get_path(), coverage])

	var runtime_loot := get_nodes_in_group("runtime_loot")
	var runtime_counts := {}
	var runtime_item_ids := {}
	var empty_shelves := 0
	var double_shelves := 0
	for child: Node in get_nodes_in_group("loot_socket"):
		var socket := child as LootSocket
		if socket == null:
			continue
		var socket_item_count := 0
		for socket_child: Node in socket.get_children():
			if socket_child.is_in_group("runtime_loot"):
				socket_item_count += 1
		if REQUIRED_ITEMS_PER_SOCKET.has(socket.socket_type):
			var required := int(socket.get_meta(
				&"loot_capacity",
				REQUIRED_ITEMS_PER_SOCKET[socket.socket_type]
			))
			if socket_item_count != required:
				failures.append("%s source=%s supports=%s has %d/%d intended items" % [
					socket.get_path(), socket.source_node, socket.support_nodes,
					socket_item_count, required,
				])
		if socket.socket_type == "shelf":
			if socket_item_count == 0:
				empty_shelves += 1
			elif socket_item_count >= 2:
				double_shelves += 1
	if empty_shelves == 0 or double_shelves == 0:
		failures.append("shelf loot distribution is still uniform")
	for child: Node in runtime_loot:
		var item := child as PickupItem
		if item == null:
			failures.append("%s is not a PickupItem" % child.get_path())
			continue
		var socket := item.get_parent() as LootSocket
		if socket == null:
			failures.append("%s is not parented to a loot socket" % item.get_path())
			continue
		runtime_counts[socket.socket_type] = int(runtime_counts.get(socket.socket_type, 0)) + 1
		runtime_item_ids[item.item_id] = int(runtime_item_ids.get(item.item_id, 0)) + 1
		if item.item_id == &"gold_bar" and socket.socket_type == "table":
			failures.append("gold bar spawned in plain sight on a table")
		var item_size: Vector3 = item.get("actual_normalized_size")
		var grounded_y := item.position.y - item_size.y * 0.5
		if (
			socket.socket_type not in ["cabinet", "wardrobe", "table", "shelf", "fridge"]
			and absf(grounded_y - PickupItem.SUPPORT_CLEARANCE) > 0.001
		):
			failures.append("%s floats %.3f above its socket" % [
				item.get_path(), grounded_y,
			])
		if (
			socket.socket_type in ["cabinet", "wardrobe"]
			and not _has_recorded_world_support(item)
		):
			failures.append("%s is not grounded on cabinet geometry" % item.get_path())
		if socket.socket_type in ["table", "shelf", "fridge"]:
			_verify_mesh_support(item, socket, failures)
		if (
			socket.socket_type in ["cabinet", "wardrobe", "fridge", "shelf", "table"]
			and not HouseLootSpawner.is_item_volume_clear(item)
		):
			failures.append("%s clips furniture or closed-door geometry" % item.get_path())
		var yaw := item.rotation.y
		var footprint_x := (
			absf(cos(yaw)) * item_size.x
			+ absf(sin(yaw)) * item_size.z
		)
		var footprint_z := (
			absf(sin(yaw)) * item_size.x
			+ absf(cos(yaw)) * item_size.z
		)
		if (
			absf(item.position.x) + footprint_x * 0.5 > socket.placement_size.x * 0.5
			or absf(item.position.z) + footprint_z * 0.5 > socket.placement_size.z * 0.5
		):
			failures.append("%s exceeds its socket footprint" % item.get_path())
		if item.collision_layer != 8 or not item.is_in_group("interactable"):
			failures.append("%s is not configured as an interactable pickup" % item.get_path())
		if not item.freeze or not item.follows_parent_support:
			failures.append("%s can fall away from its authored support" % item.get_path())
	for limited_type: String in RUNTIME_COUNT_LIMITS:
		var limits: Vector2i = RUNTIME_COUNT_LIMITS[limited_type]
		var actual := int(runtime_counts.get(limited_type, 0))
		if actual < limits.x or actual > limits.y:
			failures.append("%s loot count %d is outside %s" % [
				limited_type, actual, limits,
			])
	var shelf_total := int(runtime_counts.get("shelf", 0))
	var closed_storage_total := (
		int(runtime_counts.get("cabinet", 0))
		+ int(runtime_counts.get("wardrobe", 0))
		+ int(runtime_counts.get("fridge", 0))
	)
	if shelf_total > closed_storage_total:
		failures.append("shelf loot still dominates closed storage")
	for catalog_item: StringName in HouseLootSpawner.LOOT_DEFINITIONS:
		if int(runtime_item_ids.get(catalog_item, 0)) == 0:
			failures.append("catalog loot type %s never spawns" % catalog_item)

	for child: Node in house.find_children("*", "MovingInteractable", true, false):
		(child as MovingInteractable).set_open_immediate(false)
	await physics_frame
	await physics_frame
	for child: Node in runtime_loot:
		var item := child as PickupItem
		if item == null:
			continue
		var socket := item.get_parent() as LootSocket
		var opened_parts := _set_socket_open_state(socket, true)
		await physics_frame
		await physics_frame
		if not _has_clear_pickup_ray(item, house):
			failures.append("%s type=%s source=%s position=%s has no unobstructed pickup ray" % [
				item.get_path(),
				"unknown" if socket == null else socket.socket_type,
				NodePath() if socket == null else socket.source_node,
				item.global_position,
			])
		for moving: MovingInteractable in opened_parts:
			moving.set_open_immediate(false)
		await physics_frame

	if not runtime_loot.is_empty():
		_verify_outline(runtime_loot[0] as PickupItem, failures)
	_verify_fitted_scale_round_trip(failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("[LOOT_SOCKET_TEST] %s" % failure)
		quit(1)
		return
	print("[LOOT_SOCKET_TEST] PASS total=%d runtime_items=%d counts=%s" % [
		get_nodes_in_group("loot_socket").size(),
		runtime_loot.size(),
		counts,
	])
	quit()


func _verify_catalog(failures: Array[String]) -> void:
	var placed_ids := {}
	for socket_type: String in HouseLootSpawner.LOOT_IDS_BY_SOCKET_TYPE:
		for item_id: StringName in HouseLootSpawner.LOOT_IDS_BY_SOCKET_TYPE[socket_type]:
			placed_ids[item_id] = true
			if not HouseLootSpawner.LOOT_DEFINITIONS.has(item_id):
				failures.append("%s references undefined loot %s" % [socket_type, item_id])
	for item_id: StringName in HouseLootSpawner.LOOT_DEFINITIONS:
		var definition: Dictionary = HouseLootSpawner.LOOT_DEFINITIONS[item_id]
		if not placed_ids.has(item_id):
			failures.append("catalog loot %s has no furniture placement" % item_id)
		if load(String(definition.icon_path)) is not Texture2D:
			failures.append("catalog loot %s has no imported icon" % item_id)
		var models: Array = definition.get("models", [])
		if models.is_empty() and definition.get("model") is not PackedScene:
			failures.append("catalog loot %s has no model" % item_id)
		for model: Variant in models:
			if model is not PackedScene:
				failures.append("catalog loot %s contains an invalid model" % item_id)

	var table_items: Array = HouseLootSpawner.LOOT_IDS_BY_SOCKET_TYPE.table
	if &"gold_bar" in table_items:
		failures.append("gold bar is configured for table placement")
	for fridge_only: StringName in [&"raw_meat", &"rusty_tin", &"fish_bones"]:
		for socket_type: String in HouseLootSpawner.LOOT_IDS_BY_SOCKET_TYPE:
			if socket_type != "fridge" and fridge_only in HouseLootSpawner.LOOT_IDS_BY_SOCKET_TYPE[socket_type]:
				failures.append("%s is configured outside the fridge" % fridge_only)


func _verify_refrigerator_collision(house: Node, failures: Array[String]) -> void:
	var refrigerator := house.find_child("Refrigerador", true, false) as MeshInstance3D
	if refrigerator == null:
		failures.append("refrigerator mesh is missing")
		return
	var body := refrigerator.find_child("RefrigeradorCollision", true, false) as StaticBody3D
	if body == null:
		failures.append("refrigerator collision is missing")
		return
	var collision := body.find_child("*", true, false) as CollisionShape3D
	if collision == null or collision.shape is not ConcavePolygonShape3D:
		failures.append("refrigerator cavity is blocked by non-exact collision")


func _verify_fitted_scale_round_trip(failures: Array[String]) -> void:
	var source := PICKUP_ITEM_SCENE.instantiate() as PickupItem
	source.item_id = &"photo_frame"
	source.display_name = "Photo Frame"
	source.model_scene = PHOTO_FRAME_SCENE
	source.display_size = 1.0
	source.fit_size_limit = Vector3(0.24, 0.20, 0.24)
	root.add_child(source)
	var fitted_size := source.actual_normalized_size
	var stored_display_size := source.display_size

	var dropped := PICKUP_ITEM_SCENE.instantiate() as PickupItem
	dropped.item_id = source.item_id
	dropped.display_name = source.display_name
	dropped.model_scene = source.model_scene
	dropped.display_size = stored_display_size
	root.add_child(dropped)
	if not dropped.actual_normalized_size.is_equal_approx(fitted_size):
		failures.append(
			"fitted photo frame changes size after inventory throw: %s -> %s"
			% [fitted_size, dropped.actual_normalized_size]
		)
	source.free()
	dropped.free()


func _set_socket_open_state(socket: LootSocket, open: bool) -> Array[MovingInteractable]:
	var result: Array[MovingInteractable] = []
	if socket == null:
		return result
	var candidates: Array[NodePath] = socket.support_nodes.duplicate()
	if socket.get_parent() is MovingInteractable:
		candidates.append((socket.get_parent() as MovingInteractable).get_path())
	for path: NodePath in candidates:
		var moving := root.get_node_or_null(path) as MovingInteractable
		if moving == null or moving in result:
			continue
		moving.set_open_immediate(open)
		result.append(moving)
	return result


func _has_clear_pickup_ray(item: PickupItem, house: Node3D) -> bool:
	var target := item.global_position
	var directions := [
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		(Vector3.FORWARD + Vector3.LEFT).normalized(),
		(Vector3.FORWARD + Vector3.RIGHT).normalized(),
		(Vector3.BACK + Vector3.LEFT).normalized(),
		(Vector3.BACK + Vector3.RIGHT).normalized(),
	]
	for direction: Vector3 in directions:
		for height in [0.45, 0.75, 1.05, 1.35, 1.65]:
			var ray_start: Vector3 = target + direction * 1.2 + Vector3.UP * height
			var query := PhysicsRayQueryParameters3D.create(ray_start, target, 1 | 8)
			var hit := house.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == item:
				return true
	return false


func _verify_outline(item: PickupItem, failures: Array[String]) -> void:
	item.set_highlighted(true)
	var meshes: Array[MeshInstance3D] = []
	if item.model_instance is MeshInstance3D:
		meshes.append(item.model_instance as MeshInstance3D)
	for child: Node in item.model_instance.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	if meshes.is_empty():
		failures.append("%s has no highlightable mesh" % item.get_path())
	for mesh: MeshInstance3D in meshes:
		if not mesh.get_layer_mask_value(InteractableVisual.OUTLINE_VISIBILITY_LAYER):
			failures.append("%s did not enable its white-outline layer" % item.get_path())
			break
	item.set_highlighted(false)


func _has_recorded_world_support(item: PickupItem) -> bool:
	if not item.has_meta("ground_support_y"):
		return absf(
			item.position.y
			- item.actual_normalized_size.y * 0.5
			- PickupItem.SUPPORT_CLEARANCE
		) <= 0.001
	var bottom := item.global_position.y - item.actual_normalized_size.y * 0.5
	return absf(bottom - float(item.get_meta("ground_support_y")) - 0.003) <= 0.002


func _verify_mesh_support(
	item: PickupItem,
	socket: LootSocket,
	failures: Array[String]
) -> void:
	var support_y := HouseLootSpawner.find_item_mesh_support_y(socket, item)
	if is_nan(support_y):
		failures.append("%s is not fully supported by one source-mesh surface" % item.get_path())
		return
	var bottom := item.global_position.y - item.actual_normalized_size.y * 0.5
	var expected_bottom := support_y + PickupItem.SUPPORT_CLEARANCE
	if absf(bottom - expected_bottom) > 0.002:
		failures.append("%s is %.3f from its actual source-mesh support" % [
			item.get_path(), bottom - expected_bottom,
		])
	if not item.has_meta("mesh_support_y"):
		failures.append("%s did not record its source-mesh support" % item.get_path())
	elif absf(float(item.get_meta("mesh_support_y")) - support_y) > 0.002:
		failures.append("%s recorded the wrong source-mesh support" % item.get_path())


func _verify_drawer_socket(
	socket: Marker3D,
	drawer: SlidingInteractable,
	failures: Array[String]
) -> void:
	if socket.get_parent() != drawer:
		failures.append("%s is not parented to its drawer" % socket.get_path())
		return
	if not drawer.open_top_bounds_local.has_volume():
		failures.append("%s drawer has no container bounds" % socket.get_path())
		return
	var local_bounds := drawer.open_top_bounds_local.grow(0.02)
	if not local_bounds.has_point(socket.position):
		failures.append("%s lies outside its drawer bounds" % socket.get_path())

	drawer.set_open_immediate(false)
	var closed_position := socket.global_position
	drawer.set_open_immediate(true)
	var open_position := socket.global_position
	if closed_position.distance_to(open_position) < drawer.travel_distance * 0.8:
		failures.append("%s does not follow its opening drawer" % socket.get_path())


func _verify_hinged_socket(
	socket: Marker3D,
	door: HingedInteractable,
	failures: Array[String]
) -> void:
	if socket.get_parent() != door:
		failures.append("%s is not parented to its hinged source" % socket.get_path())
		return
	var box := door.moving_collision.shape as BoxShape3D
	if box == null:
		failures.append("%s hinged source has no box bounds" % socket.get_path())
		return
	var bounds_margin := (
		0.38
		if socket is LootSocket and (socket as LootSocket).socket_type == "fridge"
		else 0.11
	)
	var local_bounds := AABB(
		door.moving_collision.position - box.size * 0.5,
		box.size
	).grow(bounds_margin)
	if not local_bounds.has_point(socket.position):
		failures.append("%s lies outside its hinged source bounds" % socket.get_path())

	door.set_open_immediate(false)
	var closed_position := socket.global_position
	door.set_open_immediate(true, 1.0)
	var open_position := socket.global_position
	if closed_position.distance_to(open_position) < 0.08:
		failures.append("%s does not follow its hinged source" % socket.get_path())
