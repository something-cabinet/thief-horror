extends SceneTree

const HOUSE_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const SURFACE_PREFIXES := [
	"Al_",
	"Anaquel",
	"Closet",
	"Cofre",
	"Estante",
	"Estanteria",
	"Librero",
	"Mesa",
	"Refrigerador",
]


func _initialize() -> void:
	call_deferred("_audit")


func _audit() -> void:
	var house := HOUSE_SCENE.instantiate()
	root.add_child(house)
	await process_frame
	await physics_frame

	for child: Node in house.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or not _matches_prefix(mesh.name):
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		print("[LOOT_SURFACE] name=%s path=%s center=%s size=%s" % [
			mesh.name,
			house.get_path_to(mesh),
			bounds.get_center(),
			bounds.size,
		])
		if mesh.name in [&"Mesa_008", &"Librero_005"]:
			_print_upward_centers(mesh)

	for child: Node in house.find_children("*", "MovingInteractable", true, false):
		var moving := child as MovingInteractable
		if moving.moving_collision == null or moving.moving_collision.shape == null:
			continue
		var shape := moving.moving_collision.shape as BoxShape3D
		if shape == null:
			continue
		print("[MOVING_PART] name=%s type=%s center=%s size=%s" % [
			moving.name,
			moving.display_name,
			moving.to_global(moving.moving_collision.position),
			shape.size,
		])
		if moving.display_name in ["freezer door", "refrigerator door"]:
			for mesh_child: Node in moving.find_children("*", "MeshInstance3D", true, false):
				_print_upward_centers(mesh_child as MeshInstance3D)
		if moving.display_name == "drawer":
			var socket := moving.find_child("LootSocket*", true, false) as LootSocket
			var item := moving.find_child("Loot_*", true, false) as PickupItem
			if socket != null and item != null:
				print("[DRAWER_LOOT] drawer=%s socket=%s item=%s item_center=%s item_bottom=%.3f" % [
					moving.name,
					socket.global_position,
					item.display_name,
					item.global_position,
					item.global_position.y - item.actual_normalized_size.y * 0.5,
				])

	var socket_counts := {}
	var sockets_by_source := {}
	for socket: Node in get_nodes_in_group("loot_socket"):
		var type := String(socket.get("socket_type"))
		socket_counts[type] = int(socket_counts.get(type, 0)) + 1
		var source_key := String(socket.get("source_node"))
		sockets_by_source[source_key] = int(sockets_by_source.get(source_key, 0)) + 1
		if type in ["cabinet", "wardrobe"]:
			var support_names: Array[String] = []
			for support_path: NodePath in (socket as LootSocket).support_nodes:
				var support := root.get_node_or_null(support_path)
				support_names.append("missing" if support == null else String(support.name))
			print("[STORAGE_SOCKET] type=%s source=%s position=%s doors=%s" % [
				type, source_key, (socket as Node3D).global_position, support_names,
			])
	print("[LOOT_SOCKET_COUNTS] %s" % socket_counts)
	for source_key: String in sockets_by_source:
		if source_key.contains("Librero") or source_key.contains("Estanteria"):
			print("[SHELF_SOCKET_COUNT] source=%s count=%d" % [
				source_key,
				int(sockets_by_source[source_key]),
			])
	quit()


func _matches_prefix(node_name: StringName) -> bool:
	for prefix: String in SURFACE_PREFIXES:
		if String(node_name).begins_with(prefix):
			return true
	return false


func _print_upward_centers(mesh: MeshInstance3D) -> void:
	var level_data := {}
	for surface_index in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in count:
			var ids := PackedInt32Array([
				indices[triangle_index * 3] if not indices.is_empty() else triangle_index * 3,
				indices[triangle_index * 3 + 1] if not indices.is_empty() else triangle_index * 3 + 1,
				indices[triangle_index * 3 + 2] if not indices.is_empty() else triangle_index * 3 + 2,
			])
			var a := mesh.global_transform * vertices[ids[0]]
			var b := mesh.global_transform * vertices[ids[1]]
			var c := mesh.global_transform * vertices[ids[2]]
			var cross := (b - a).cross(c - a)
			var area := cross.length() * 0.5
			if area < 0.0004 or absf(cross.normalized().y) < 0.72:
				continue
			var centroid := (a + b + c) / 3.0
			var key := roundi(centroid.y * 40.0)
			if not level_data.has(key):
				level_data[key] = {"area": 0.0, "weighted": Vector3.ZERO}
			level_data[key].area += area
			level_data[key].weighted += centroid * area
	for key: int in level_data:
		var data: Dictionary = level_data[key]
		print("[UPWARD_SURFACE] mesh=%s center=%s area=%.4f" % [
			mesh.name,
			data.weighted / data.area,
			data.area,
		])
