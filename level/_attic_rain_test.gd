extends Node

const LEVEL := preload("res://level/Level1.tscn")


func _ready() -> void:
	var level := LEVEL.instantiate()
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	get_tree().current_scene = level
	var player := level.find_child("Player", true, false) as Player
	player.global_position = Vector3(-42.889, 4.379, -125.627)
	player.rotation.y = deg_to_rad(62.1)
	player.player_camera.rotation.x = deg_to_rad(5.4)
	for child: Node in player.find_children("*", "CanvasLayer", true, false):
		child.visible = false
	for frame in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/attic-rain-on.png")
	var rain := level.get_node("Rain")
	var emitter := rain.get_node("WorldRain") as GPUParticles3D
	emitter.visible = false
	for frame in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/attic-rain-off.png")
	get_tree().quit()
