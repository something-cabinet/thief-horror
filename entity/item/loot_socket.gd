extends Marker3D
class_name LootSocket

@export_enum("drawer", "cabinet", "fridge", "wardrobe", "shelf", "table", "floor_hidden")
var socket_type := "shelf"
@export var max_item_size := Vector3(0.3, 0.3, 0.3)
@export var placement_size := Vector3(0.3, 0.3, 0.3)
@export var source_node := NodePath()
@export var support_nodes: Array[NodePath] = []


func configure(
	type: String,
	size_limit: Vector3,
	source: Node,
	placement_limit: Vector3 = Vector3.ZERO
) -> void:
	socket_type = type
	max_item_size = size_limit
	placement_size = size_limit if placement_limit.is_zero_approx() else placement_limit
	if source != null and source.is_inside_tree():
		source_node = source.get_path()
		support_nodes.append(source_node)
	add_to_group("loot_socket")


func add_support(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var path := node.get_path()
	if path not in support_nodes:
		support_nodes.append(path)
