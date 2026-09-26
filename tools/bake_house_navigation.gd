extends SceneTree

# Rebuild after changing the house geometry or its generated collisions:
# godot --headless --path . --script res://tools/bake_house_navigation.gd

const MAP_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const OUTPUT_PATH := "res://level/house_navigation_mesh.tres"


func _init() -> void:
	var map := MAP_SCENE.instantiate()
	root.add_child(map)
	await physics_frame
	await physics_frame

	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = (
		NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	)
	navigation_mesh.geometry_collision_mask = 1
	navigation_mesh.cell_size = 0.15
	navigation_mesh.cell_height = 0.05
	navigation_mesh.agent_height = 1.55
	navigation_mesh.agent_radius = 0.30
	navigation_mesh.agent_max_climb = 0.35
	navigation_mesh.agent_max_slope = 46.0
	navigation_mesh.region_min_size = 1.0
	navigation_mesh.region_merge_size = 10.0
	navigation_mesh.edge_max_length = 6.0
	navigation_mesh.edge_max_error = 1.0
	navigation_mesh.detail_sample_distance = 1.0
	navigation_mesh.detail_sample_max_error = 0.2
	navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-65.0, -5.0, -145.0),
		Vector3(55.0, 16.0, 62.0)
	)

	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		navigation_mesh,
		source_geometry,
		map
	)
	NavigationServer3D.bake_from_source_geometry_data(
		navigation_mesh,
		source_geometry
	)
	var save_error := ResourceSaver.save(navigation_mesh, OUTPUT_PATH)
	if save_error != OK:
		push_error("Failed to save house navigation: %s" % error_string(save_error))
		quit(1)
		return
	print("HOUSE_NAVIGATION polygons=%d vertices=%d" % [
		navigation_mesh.get_polygon_count(),
		navigation_mesh.vertices.size(),
	])
	quit(0)
