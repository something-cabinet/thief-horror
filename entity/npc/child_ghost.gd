extends Node3D
class_name ChildGhost

const GHOST_TEXTURE := preload(
	"res://asset/model/characters/child_ghost/ChildGhost_Texture.png"
)
const HUMANOID_ANIMATIONS := preload(
	"res://asset/animation/humanoid/mesh2motion_human_base.glb"
)

@export var float_height := 0.08
@export var float_speed := 1.25
@export var sway_degrees := 2.0

var _rest_position: Vector3
var _time_offset := 0.0
var _skeleton: Skeleton3D


func _ready() -> void:
	_rest_position = position
	_time_offset = randf_range(0.0, TAU)
	_skeleton = find_child("GeneralSkeleton", true, false) as Skeleton3D
	if _skeleton != null:
		_shorten_bone(&"LeftLowerLeg", 0.78)
		_shorten_bone(&"LeftFoot", 0.78)
		_shorten_bone(&"RightLowerLeg", 0.78)
		_shorten_bone(&"RightFoot", 0.78)
		_shorten_bone(&"LeftLowerArm", 0.86)
		_shorten_bone(&"LeftHand", 0.86)
		_shorten_bone(&"RightLowerArm", 0.86)
		_shorten_bone(&"RightHand", 0.86)
		_add_flat_cap()

	var overlay := ShaderMaterial.new()
	overlay.shader = preload("res://entity/npc/child_ghost_overlay.gdshader")
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if String(mesh.name).begins_with("FlatCap"):
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_texture = GHOST_TEXTURE
			material.albedo_color = Color(0.78, 0.88, 0.96, 0.88)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = Color(0.10, 0.28, 0.40)
			material.emission_energy_multiplier = 0.35
			material.roughness = 0.9
			mesh.set_surface_override_material(surface_index, material)
		mesh.material_overlay = overlay
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		if player.has_animation_library(&"humanoid"):
			player.remove_animation_library(&"humanoid")
		player.add_animation_library(&"humanoid", HUMANOID_ANIMATIONS)
		var idle := player.get_animation(&"humanoid/Zombie_Idle")
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
		player.speed_scale = 0.55
		player.play(&"humanoid/Zombie_Idle")


func _process(_delta: float) -> void:
	if _skeleton != null:
		var head_bone := _skeleton.find_bone("Head")
		if head_bone >= 0:
			_skeleton.set_bone_pose_scale(head_bone, Vector3.ONE * 1.36)
	var phase := Time.get_ticks_msec() * 0.001 * float_speed + _time_offset
	position = _rest_position + Vector3.UP * (sin(phase) * float_height)
	rotation_degrees.z = sin(phase * 0.63) * sway_degrees
	var glow := get_node_or_null("GhostGlow") as OmniLight3D
	if glow != null:
		glow.light_energy = 0.28 + sin(phase * 1.7) * 0.06


func _shorten_bone(bone_name: StringName, factor: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest := _skeleton.get_bone_rest(bone)
	rest.origin *= factor
	_skeleton.set_bone_rest(bone, rest)


func _add_flat_cap() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = "FlatCapAttachment"
	attachment.bone_name = "Head"
	_skeleton.add_child(attachment)

	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.025, 0.032, 0.04, 1.0)
	cap_material.roughness = 0.96

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.105
	crown_mesh.height = 0.08
	crown_mesh.radial_segments = 12
	crown_mesh.rings = 4
	crown_mesh.material = cap_material
	var crown := MeshInstance3D.new()
	crown.name = "FlatCapCrown"
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, 0.185, 0.0)
	crown.scale = Vector3(1.1, 1.0, 0.95)
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment.add_child(crown)

	var brim_mesh := BoxMesh.new()
	brim_mesh.size = Vector3(0.15, 0.018, 0.07)
	brim_mesh.material = cap_material
	var brim := MeshInstance3D.new()
	brim.name = "FlatCapBrim"
	brim.mesh = brim_mesh
	brim.position = Vector3(0.0, 0.17, 0.075)
	brim.rotation_degrees.x = 8.0
	brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment.add_child(brim)
