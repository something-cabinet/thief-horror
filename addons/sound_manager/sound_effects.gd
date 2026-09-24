extends "res://addons/sound_manager/abstract_audio_player_pool.gd"

func play(resource: AudioStream, override_bus: String = "", randomize_pitch = false) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = prepare(resource, override_bus)
	if randomize_pitch:
		player.pitch_scale = randf_range(0.8, 1.2)
	else:
		player.pitch_scale = 1
	player.call_deferred("play")
	return player
