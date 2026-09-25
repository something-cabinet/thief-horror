extends RefCounted
class_name InteractableVisual

const OUTLINE_VISIBILITY_LAYER := 20


static func set_highlighted(root: Node, highlighted: bool) -> void:
	if root == null:
		return
	if root is MeshInstance3D:
		(root as MeshInstance3D).set_layer_mask_value(
			OUTLINE_VISIBILITY_LAYER,
			highlighted
		)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).set_layer_mask_value(
			OUTLINE_VISIBILITY_LAYER,
			highlighted
		)
