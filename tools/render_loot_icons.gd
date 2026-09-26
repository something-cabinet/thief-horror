extends SceneTree

const OUTPUT_DIRECTORY := "res://asset/ui/loot_icons"
const ICON_SIZE := 256
const ITEMS := {
	&"cash": preload("res://asset/model/loot_pack/cash_1.glb"),
	&"coins": preload("res://asset/model/loot_pack/coin_mp_1.glb"),
	&"pills": preload("res://asset/model/loot_pack/pills_bottle_1.glb"),
	&"canned_food": preload("res://asset/model/loot_pack/canned_food_mp_1.glb"),
	&"book": preload("res://asset/model/loot_pack/book_mp_1.glb"),
	&"photo_frame": preload("res://asset/model/loot_pack/photo_frame_mp_1.glb"),
	&"painting": preload("res://asset/model/loot_pack/painting_1.glb"),
	&"gold_bar": preload("res://asset/model/loot_pack/gold_bar_pcs_1.glb"),
	&"cigarettes": preload("res://asset/model/items/models/cigs_carton.glb"),
	&"notebook": preload("res://asset/model/items/models/ps1_notebook.glb"),
	&"antique_radio": preload("res://asset/model/items/models/ps1_antique_radio.glb"),
	&"bankers_lamp": preload("res://asset/model/items/models/ps1_brass_bankers_desk_lamp.glb"),
	&"clock": preload("res://asset/model/loot_pack/clock_1.glb"),
	&"cross": preload("res://asset/model/loot_pack/cross_1.glb"),
	&"ashtray": preload("res://asset/model/loot_pack/ashtray_1.glb"),
	&"lighter": preload("res://asset/model/loot_pack/lighter_mp_1.glb"),
	&"matches": preload("res://asset/model/loot_pack/matchbox_1.glb"),
	&"glass_bottle": preload("res://asset/model/loot_pack/glass_bottle_1.glb"),
	&"plate": preload("res://asset/model/loot_pack/plate_mp_1.glb"),
	&"cutlery": preload("res://asset/model/loot_pack/spoon_mp_1.glb"),
	&"writing_tools": preload("res://asset/model/loot_pack/pen_mp_1.glb"),
	&"magnet": preload("res://asset/model/loot_pack/magnet_mp_1.glb"),
	&"flashlight": preload("res://asset/model/loot_pack/flashlight_1.glb"),
	&"battery": preload("res://asset/model/loot_pack/battery_mp_1.glb"),
	&"medicine_packet": preload("res://asset/model/loot_pack/pills_packet_1.glb"),
	&"loose_pills": preload("res://asset/model/loot_pack/pills_1.glb"),
	&"bandage": preload("res://asset/model/loot_pack/bandage_mp_1.glb"),
	&"syringe": preload("res://asset/model/loot_pack/syringe_mp_1.glb"),
	&"raw_meat": preload("res://asset/model/loot_pack/meat_1.glb"),
	&"lollipop": preload("res://asset/model/loot_pack/lollipop_mp_1.glb"),
	&"kitchen_knife": preload("res://asset/model/loot_pack/butcher_knife_mp_1.glb"),
	&"hand_saw": preload("res://asset/model/loot_pack/hand_saw_1.glb"),
	&"screwdriver": preload("res://asset/model/loot_pack/screwdriver_mp_1.glb"),
	&"nails": preload("res://asset/model/loot_pack/nails_1.glb"),
	&"rusty_tin": preload("res://asset/model/loot_pack/tin_can_mp_1_rusty.glb"),
	&"fish_bones": preload("res://asset/model/loot_pack/fish_skeleton_mp_1.glb"),
	&"sponge": preload("res://asset/model/loot_pack/sponge_mp_1.glb"),
	&"potted_plant": preload("res://asset/model/loot_pack/potted_cactus_mp_1.glb"),
}
const ICON_POSES := {
	&"cash": Vector3(-18.0, -28.0, -8.0),
	&"coins": Vector3(22.0, 18.0, -8.0),
	&"pills": Vector3(-8.0, -24.0, 0.0),
	&"canned_food": Vector3(-8.0, -26.0, 0.0),
	&"book": Vector3(-22.0, -28.0, -8.0),
	&"photo_frame": Vector3(-8.0, -22.0, 0.0),
	&"painting": Vector3(-8.0, -18.0, 0.0),
	&"gold_bar": Vector3(-18.0, -28.0, -6.0),
	&"cigarettes": Vector3(-16.0, -26.0, -6.0),
	&"notebook": Vector3(-18.0, -26.0, -6.0),
	&"antique_radio": Vector3(-8.0, -24.0, 0.0),
	&"bankers_lamp": Vector3(-6.0, -22.0, 0.0),
	&"clock": Vector3(-8.0, -24.0, 0.0),
	&"cross": Vector3(-10.0, -20.0, -6.0),
	&"ashtray": Vector3(-20.0, -28.0, -5.0),
	&"lighter": Vector3(-15.0, -25.0, -5.0),
	&"matches": Vector3(-15.0, -25.0, -8.0),
	&"glass_bottle": Vector3(-5.0, -25.0, 0.0),
	&"plate": Vector3(-30.0, -18.0, 0.0),
	&"cutlery": Vector3(-22.0, -28.0, -8.0),
	&"writing_tools": Vector3(-22.0, -28.0, -8.0),
	&"magnet": Vector3(-15.0, -20.0, 0.0),
	&"flashlight": Vector3(-12.0, -28.0, -8.0),
	&"battery": Vector3(-12.0, -24.0, 0.0),
	&"medicine_packet": Vector3(-20.0, -28.0, -8.0),
	&"loose_pills": Vector3(-20.0, -25.0, 0.0),
	&"bandage": Vector3(-20.0, -28.0, 0.0),
	&"syringe": Vector3(-20.0, -25.0, -5.0),
	&"raw_meat": Vector3(-20.0, -28.0, -8.0),
	&"lollipop": Vector3(-20.0, -28.0, -8.0),
	&"kitchen_knife": Vector3(-20.0, -28.0, -8.0),
	&"hand_saw": Vector3(-18.0, -28.0, -8.0),
	&"screwdriver": Vector3(-18.0, -28.0, -8.0),
	&"nails": Vector3(-20.0, -25.0, 0.0),
	&"rusty_tin": Vector3(-10.0, -24.0, 0.0),
	&"fish_bones": Vector3(-20.0, -28.0, -8.0),
	&"sponge": Vector3(-20.0, -25.0, 0.0),
	&"potted_plant": Vector3(-8.0, -24.0, 0.0),
}

var stage: Node3D
var camera: Camera3D
var viewport: SubViewport


func _initialize() -> void:
	call_deferred("_render_icons")


func _render_icons() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	_setup_stage()
	for item_id: StringName in ITEMS:
		await _render_icon(item_id, ITEMS[item_id] as PackedScene)
	print("[LOOT_ICONS] rendered=%d directory=%s" % [ITEMS.size(), OUTPUT_DIRECTORY])
	quit()


func _setup_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.84)
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.91, 0.76)
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.48, 0.62, 1.0)
	fill.light_energy = 0.75
	fill.rotation_degrees = Vector3(36.0, 142.0, 0.0)
	stage.add_child(fill)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(2.4, 1.75, 2.8)
	stage.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true


func _render_icon(item_id: StringName, model_scene: PackedScene) -> void:
	var pivot := Node3D.new()
	stage.add_child(pivot)
	var model := model_scene.instantiate() as Node3D
	pivot.add_child(model)
	var bounds := _calculate_model_bounds(model)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_side <= 0.0001:
		pivot.free()
		return
	var scale_factor := 1.22 / longest_side
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor
	pivot.rotation_degrees = ICON_POSES.get(item_id, Vector3.ZERO)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output_path := ProjectSettings.globalize_path(
		OUTPUT_DIRECTORY.path_join("%s.png" % item_id)
	)
	viewport.get_texture().get_image().save_png(output_path)
	pivot.free()
	await process_frame


func _calculate_model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var has_point := false
	var inverse_root := model.global_transform.affine_inverse()
	var meshes: Array[MeshInstance3D] = []
	if model is MeshInstance3D:
		meshes.append(model as MeshInstance3D)
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var local_transform := inverse_root * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.mesh.get_aabb()
		var bounds_end := mesh_bounds.end
		for x in [mesh_bounds.position.x, bounds_end.x]:
			for y in [mesh_bounds.position.y, bounds_end.y]:
				for z in [mesh_bounds.position.z, bounds_end.z]:
					var point := local_transform * Vector3(x, y, z)
					result = AABB(point, Vector3.ZERO) if not has_point else result.expand(point)
					has_point = true
	return result
