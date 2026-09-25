extends Node

const LEVEL := preload("res://level/Level1.tscn")
const SAMPLE := Vector3(-42.889, 4.379, -125.627)


func _ready() -> void:
	var level := LEVEL.instantiate()
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for child: Node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if String(mesh_instance.name).begins_with("Telaraña"):
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index)
				print("[COBWEB_MATERIAL] mesh=%s surface=%d material=%s class=%s" % [
					mesh_instance.name,
					surface_index,
					material.resource_name if material != null else "null",
					material.get_class() if material != null else "null",
				])
				if material is StandardMaterial3D:
					var standard := material as StandardMaterial3D
					print("[COBWEB_MATERIAL] alpha=%s transparency=%d emission=%s vertex_color=%s texture=%s" % [
						standard.albedo_color.a,
						standard.transparency,
						standard.emission_enabled,
						standard.vertex_color_use_as_albedo,
						standard.albedo_texture.resource_path if standard.albedo_texture != null else "null",
					])
		var bounds: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if SAMPLE.x >= bounds.position.x - 2.0 and SAMPLE.x <= bounds.end.x + 2.0 \
			and SAMPLE.z >= bounds.position.z - 2.0 and SAMPLE.z <= bounds.end.z + 2.0:
			print("[ROOF_INVENTORY] name=%s path=%s aabb=%s layers=%d visible=%s" % [
				mesh_instance.name,
				mesh_instance.get_path(),
				bounds,
				mesh_instance.layers,
				mesh_instance.visible,
			])
	get_tree().quit()
