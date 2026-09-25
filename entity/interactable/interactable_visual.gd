# Highlights an interactable by toggling visibility layer 20 on every mesh under it.
#
# How it works:
# - Only the render-layer bit changes; materials and shaders are untouched, so it
#   works for any object. Meshes keep layer 1, so the main camera still draws them.
# - Layer 20 matches the player's outline camera (cull_mask = 1 << 19; editor
#   layers are 1-based, bits are 0-based). That camera renders only highlighted
#   meshes into a transparent SubViewport, and interaction_outline.gdshader draws
#   an edge around the resulting silhouette (see Player._setup_interaction_outline_overlay).
# - find_children(..., owned = false) also reaches meshes inside instanced
#   .glb/.fbx models, which are not owned by the scene. The root is checked
#   separately because find_children only searches descendants.
#
# Limitations:
# - Only MeshInstance3D is marked; CSG, MultiMesh, Sprite3D and particles are not.
# - Layer 20 is reserved: a mesh set to it in the editor is always outlined, and
#   un-highlighting clears that bit.
# - Every mesh below root is affected, including other objects parented under it.
# - Highlighted meshes that touch share one combined outline.
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
