@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	for player_node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := player_node as AnimationPlayer
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				_remove_non_skeleton_tracks(library.get_animation(animation_name))
	return scene


func _remove_non_skeleton_tracks(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_path(track_index).get_subname_count() == 0:
			animation.remove_track(track_index)
