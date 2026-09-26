@tool
extends SceneTree

const MESH2MOTION_ANIMATIONS := "res://asset/animation/humanoid/mesh2motion_human_base.glb"
const MESH2MOTION_BONE_MAP := "res://asset/animation/humanoid/mesh2motion_humanoid_bone_map.tres"
const ANIMATION_POST_IMPORT := "res://tools/humanoid_animation_post_import.gd"
const MIXAMO_BONE_MAP := "res://asset/animation/humanoid/mixamo_humanoid_bone_map.tres"
const MIXAMO_CHARACTERS := [
	"res://asset/model/characters/grandma/Grandma.fbx",
	"res://asset/model/characters/grandma/GrandmaPurple.fbx",
]


func _init() -> void:
	_configure_mesh2motion_library()
	var character_paths: PackedStringArray = OS.get_cmdline_user_args()
	if character_paths.is_empty():
		character_paths = PackedStringArray(MIXAMO_CHARACTERS)
	for path in character_paths:
		_configure_mixamo_character(path)
	quit()


func _configure_mesh2motion_library() -> void:
	var path := MESH2MOTION_ANIMATIONS + ".import"
	var config := _load_import_config(path)
	var imported_path: String = config.get_value("remap", "path", "")
	if imported_path.ends_with(".scn"):
		imported_path = imported_path.trim_suffix(".scn") + ".res"
	config.set_value("remap", "importer", "animation_library")
	config.set_value("remap", "type", "AnimationLibrary")
	config.set_value("remap", "path", imported_path)
	config.set_value("deps", "dest_files", PackedStringArray([imported_path]))
	config.set_value("params", "import_script/path", ANIMATION_POST_IMPORT)
	config.set_value("params", "_subresources", {
		"nodes": {
			"PATH:Armature/Skeleton3D": _humanoid_settings(load(MESH2MOTION_BONE_MAP), false),
		},
	})
	_save_import_config(config, path)


func _configure_mixamo_character(source_path: String) -> void:
	var path := source_path + ".import"
	var config := _load_import_config(path)
	config.set_value("params", "animation/import", false)
	config.set_value("params", "_subresources", {
		"nodes": {
			"PATH:Skeleton3D": _humanoid_settings(load(MIXAMO_BONE_MAP), true),
		},
	})
	_save_import_config(config, path)


func _humanoid_settings(bone_map: BoneMap, fix_silhouette: bool) -> Dictionary:
	return {
		"retarget/bone_map": bone_map,
		"retarget/remove_tracks/except_bone_transform": false,
		"retarget/remove_tracks/unimportant_positions": true,
		"retarget/remove_tracks/unmapped_bones": 1,
		"retarget/bone_renamer/rename_bones": true,
		"retarget/bone_renamer/unique_node/make_unique": true,
		"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",
		"retarget/rest_fixer/apply_node_transforms": true,
		"retarget/rest_fixer/normalize_position_tracks": true,
		"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
		"retarget/rest_fixer/retarget_method": 1,
		"retarget/rest_fixer/keep_global_rest_on_leftovers": true,
		"retarget/rest_fixer/fix_silhouette/enable": fix_silhouette,
		"retarget/rest_fixer/fix_silhouette/filter": [
			&"LeftFoot",
			&"LeftToes",
			&"RightFoot",
			&"RightToes",
		],
		"retarget/rest_fixer/fix_silhouette/threshold": 15.0,
		"retarget/rest_fixer/fix_silhouette/base_height_adjustment": 0.0,
	}


func _load_import_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		push_error("Import %s once before configuring it (error %s)." % [path, error])
		quit(1)
	return config


func _save_import_config(config: ConfigFile, path: String) -> void:
	var error := config.save(path)
	if error != OK:
		push_error("Could not save %s (error %s)." % [path, error])
		quit(1)
