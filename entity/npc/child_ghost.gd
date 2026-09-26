extends GrandmaNpc
class_name ChildGhost

const CHILD_TEXTURE := preload(
	"res://asset/model/characters/child_ghost/ChildGhost_Texture.png"
)


func _ready() -> void:
	super._ready()
	remove_from_group("interactable")
	if skeleton != null:
		_shorten_bone(&"LeftLowerLeg", 0.78)
		_shorten_bone(&"LeftFoot", 0.78)
		_shorten_bone(&"RightLowerLeg", 0.78)
		_shorten_bone(&"RightFoot", 0.78)
		_shorten_bone(&"LeftLowerArm", 0.86)
		_shorten_bone(&"LeftHand", 0.86)
		_shorten_bone(&"RightLowerArm", 0.86)
		_shorten_bone(&"RightHand", 0.86)
		_add_flat_cap()
	_apply_lit_materials()


func _process(delta: float) -> void:
	super._process(delta)
	if skeleton == null:
		return
	var head_bone := skeleton.find_bone(&"Head")
	if head_bone >= 0:
		skeleton.set_bone_pose_scale(head_bone, Vector3.ONE * 1.36)


func _apply_lit_materials() -> void:
	if model_instance == null:
		return
	for child in model_instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if String(mesh.name).begins_with("FlatCap"):
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_texture = CHILD_TEXTURE
			material.albedo_color = Color(0.94, 0.94, 0.91, 1.0)
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.emission_enabled = false
			material.roughness = 0.9
			mesh.set_surface_override_material(surface_index, material)
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _shorten_bone(bone_name: StringName, factor: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest := skeleton.get_bone_rest(bone)
	rest.origin *= factor
	skeleton.set_bone_rest(bone, rest)


func _add_flat_cap() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = "FlatCapAttachment"
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)

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
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	attachment.add_child(crown)

	var brim_mesh := BoxMesh.new()
	brim_mesh.size = Vector3(0.15, 0.018, 0.07)
	brim_mesh.material = cap_material
	var brim := MeshInstance3D.new()
	brim.name = "FlatCapBrim"
	brim.mesh = brim_mesh
	brim.position = Vector3(0.0, 0.17, 0.075)
	brim.rotation_degrees.x = 8.0
	brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	attachment.add_child(brim)
