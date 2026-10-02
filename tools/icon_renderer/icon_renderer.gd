@tool
extends Control

## Renders a model to a transparent PNG item icon.
##
## How to use:
## 1. Open res://tools/icon_renderer/IconRenderer.tscn and select the root node.
## 2. Drag a model (.glb or scene) into `model` in the Inspector.
## 3. Optional: adjust `pose_degrees` (viewing angle) and `model_size` (how much
##    of the frame it fills). Select Preview/Viewport/Camera3D and use its
##    camera preview to check the framing; it updates live in the editor.
## 4. Press F6 (Run Current Scene). A window opens briefly, saves the PNG, and
##    closes. Untick `quit_when_done` to keep it open and inspect the result.
## 5. The PNG is saved to DEFAULT_OUTPUT_DIRECTORY/<model file name>.png, or to
##    `output_path` if set. Return to the editor so it imports the file, then
##    assign it to the `icon` field of the item's pickup scene.
##
## Lighting and camera are nodes in the scene (KeyLight, FillLight,
## WorldEnvironment, Camera3D); edit them there to change every icon's look.

const DEFAULT_OUTPUT_DIRECTORY := "res://asset/model/items/icons"

@export var model: PackedScene:
	set(value):
		model = value
		_refresh_preview()
## Rotation applied to the model before rendering.
@export var pose_degrees := Vector3(-12.0, -28.0, -8.0):
	set(value):
		pose_degrees = value
		if pivot != null:
			pivot.rotation_degrees = pose_degrees
## Leave empty to save as <model file name>.png in DEFAULT_OUTPUT_DIRECTORY.
@export_file("*.png") var output_path := ""
@export var icon_size := 256
## Render this many times larger, then downscale for smoother edges.
@export_range(1, 4) var supersample := 2
## Size of the model's longest side; raise to fill more of the icon.
@export_range(0.2, 2.0, 0.01) var model_size := 1.22:
	set(value):
		model_size = value
		_refresh_preview()
@export var quit_when_done := true

@onready var viewport: SubViewport = $Preview/Viewport
@onready var pivot: Node3D = $Preview/Viewport/Pivot


func _ready() -> void:
	_refresh_preview()
	if Engine.is_editor_hint():
		return
	if model == null:
		push_error("IconRenderer: set `model` in the Inspector before running.")
		return
	await _render()
	if quit_when_done:
		get_tree().quit()


func _render() -> void:
	viewport.size = Vector2i.ONE * icon_size * supersample
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if supersample > 1:
		image.resize(icon_size, icon_size, Image.INTERPOLATE_LANCZOS)
	var path := _resolve_output_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := image.save_png(path)
	if error != OK:
		push_error("IconRenderer: failed to save %s (%s)" % [path, error_string(error)])
		return
	print("[ICON_RENDERER] saved %s" % path)


func _resolve_output_path() -> String:
	if not output_path.is_empty():
		return output_path
	return DEFAULT_OUTPUT_DIRECTORY.path_join(model.resource_path.get_file().get_basename() + ".png")


func _refresh_preview() -> void:
	if pivot == null:
		return
	# The model is never owned by the scene, so it isn't saved into it.
	for child in pivot.get_children():
		child.free()
	pivot.rotation_degrees = pose_degrees
	if model == null:
		return
	var instance := model.instantiate() as Node3D
	pivot.add_child(instance)
	var bounds := _calculate_model_bounds(instance)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_side <= 0.0001:
		return
	var scale_factor := model_size / longest_side
	instance.scale = Vector3.ONE * scale_factor
	instance.position = -bounds.get_center() * scale_factor


func _calculate_model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var has_point := false
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: Node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# Accumulate transforms by hand: this runs before the nodes are drawn.
		var local_transform := Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != root and current is Node3D:
			local_transform = (current as Node3D).transform * local_transform
			current = current.get_parent()
		var mesh_bounds := mesh_instance.mesh.get_aabb()
		for x in [mesh_bounds.position.x, mesh_bounds.end.x]:
			for y in [mesh_bounds.position.y, mesh_bounds.end.y]:
				for z in [mesh_bounds.position.z, mesh_bounds.end.z]:
					var point: Vector3 = local_transform * Vector3(x, y, z)
					result = AABB(point, Vector3.ZERO) if not has_point else result.expand(point)
					has_point = true
	return result
