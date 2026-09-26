extends SceneTree

const ANIMATION_LIBRARY_PATH := "res://asset/animation/humanoid/mesh2motion_human_base.glb"
const CHARACTER_PATHS := [
	"res://asset/model/characters/grandma/Grandma.fbx",
	"res://asset/model/characters/grandma/GrandmaPurple.fbx",
]
const REQUIRED_ANIMATIONS := [
	&"Idle_A",
	&"Idle_Talking",
	&"Idle_ShakeOff",
	&"Walk",
]

var failures: Array[String] = []


func _init() -> void:
	var library := load(ANIMATION_LIBRARY_PATH) as AnimationLibrary
	if library == null:
		_finish(["Could not load %s." % ANIMATION_LIBRARY_PATH])
		return

	_validate_library(library)
	for character_path in CHARACTER_PATHS:
		_validate_character(character_path, library)
	_finish(failures)


func _validate_library(library: AnimationLibrary) -> void:
	if library.get_animation_list().size() != 87:
		failures.append("Expected 87 Mesh2Motion animations.")
	for required_animation in REQUIRED_ANIMATIONS:
		if not library.has_animation(required_animation):
			failures.append("Missing animation %s." % required_animation)
	for animation_name in library.get_animation_list():
		var animation := library.get_animation(animation_name)
		for track_index in animation.get_track_count():
			if animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D:
				failures.append("%s contains a scale track." % animation_name)
			var track_path := animation.track_get_path(track_index)
			if track_path.get_concatenated_names() != "%GeneralSkeleton" or track_path.get_subname_count() != 1:
				failures.append("%s contains invalid track %s." % [animation_name, track_path])


func _validate_character(character_path: String, library: AnimationLibrary) -> void:
	var packed_scene := load(character_path) as PackedScene
	if packed_scene == null:
		failures.append("Could not load %s." % character_path)
		return
	var character := packed_scene.instantiate()
	root.add_child(character)
	var players := character.find_children("*", "AnimationPlayer", true, false)
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		failures.append("%s has no AnimationPlayer or Skeleton3D." % character_path)
		character.free()
		return

	var player := players[0] as AnimationPlayer
	var skeleton := skeletons[0] as Skeleton3D
	player.add_animation_library(&"humanoid", library)
	for animation_name in REQUIRED_ANIMATIONS:
		if not player.has_animation(&"humanoid/" + animation_name):
			failures.append("%s cannot play %s." % [character_path, animation_name])

	var leg := skeleton.find_bone(&"LeftUpperLeg")
	var hand := skeleton.find_bone(&"LeftHand")
	if leg < 0 or hand < 0:
		failures.append("%s is not mapped to humanoid bone names." % character_path)
		character.free()
		return
	player.play(&"humanoid/Walk")
	player.seek(0.0, true)
	var leg_start := skeleton.get_bone_pose_rotation(leg)
	var hand_start := skeleton.get_bone_pose_rotation(hand)
	player.seek(0.25, true)
	if leg_start.is_equal_approx(skeleton.get_bone_pose_rotation(leg)):
		failures.append("%s walk does not animate the leg." % character_path)
	if hand_start.is_equal_approx(skeleton.get_bone_pose_rotation(hand)):
		failures.append("%s walk does not animate the hand." % character_path)
	character.free()


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("HUMANOID_PIPELINE_OK")
		quit()
		return
	for error in errors:
		push_error(error)
	quit(1)
