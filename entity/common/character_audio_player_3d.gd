extends Node3D
class_name CharacterAudioPlayer3D

@export var default_busses = ["SFX", "Sounds"]
@export var default_pool_size = 4
@export var bus: String = "SFX"

var available_players: Array[AudioStreamPlayer3D] = []
var busy_players: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	for possible_bus in default_busses:
		var cases: PackedStringArray = [
			possible_bus,
			possible_bus.to_lower(),
			possible_bus.to_camel_case(),
			possible_bus.to_pascal_case(),
			possible_bus.to_snake_case()
		]
		for case in cases:
			if AudioServer.get_bus_index(case) > - 1:
				bus = case
				break

	for i in default_pool_size:
		increase_pool()

func prepare(resource: AudioStream, override_bus: String="") -> AudioStreamPlayer3D:
	var player := get_available_player()
	player.stream = resource
	player.bus = override_bus if override_bus != "" else bus
	player.volume_db = linear_to_db(1.0)
	player.pitch_scale = 1
	return player

func get_available_player() -> AudioStreamPlayer3D:
	if available_players.size() == 0:
		increase_pool()
	var player = available_players.pop_front()
	busy_players.append(player)
	return player

func mark_player_as_available(player: AudioStreamPlayer3D) -> void:
	if busy_players.has(player):
		busy_players.erase(player)

	if not available_players.has(player):
		available_players.append(player)

func increase_pool() -> void:
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	available_players.append(player)
	player.bus = bus
	player.finished.connect(_on_player_finished.bind(player))

func play(resource: AudioStream, override_bus: String="", randomize_pitch=false) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = prepare(resource, override_bus)
	if randomize_pitch:
		player.pitch_scale = randf_range(0.8, 1.2)
	else:
		player.pitch_scale = 1
	player.call_deferred("play")
	return player

### SIGNALS

func _on_player_finished(player: AudioStreamPlayer3D) -> void:
	mark_player_as_available(player)
