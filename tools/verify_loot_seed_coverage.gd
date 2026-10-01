extends SceneTree

const HOUSE_SCENE := preload("res://level/AbandonedHouseMap.tscn")
const SEEDS := [0, 1, 2, 3, 4, 17, 42, 99, 313, 1337, 9001, 65535]
const DEFAULT_CAPACITY := {
	"drawer": 1,
	"cabinet": 1,
	"wardrobe": 1,
	"fridge": 2,
}


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	ProjectSettings.set_setting("thief_horror/disable_runtime_loot", true)
	var house := HOUSE_SCENE.instantiate()
	root.add_child(house)
	await process_frame
	await physics_frame
	var sockets: Array[Node] = get_nodes_in_group("loot_socket")
	var failures: Array[String] = []
	for seed: int in SEEDS:
		for child: Node in get_nodes_in_group("runtime_loot"):
			child.free()
		for child: Node in house.find_children("*", "MovingInteractable", true, false):
			(child as MovingInteractable).set_open_immediate(false)
		await physics_frame
		HouseLootSpawner.spawn_for_sockets(sockets, seed, true)
		await process_frame
		await physics_frame
		for child: Node in sockets:
			var socket := child as LootSocket
			if socket == null or not DEFAULT_CAPACITY.has(socket.socket_type):
				continue
			var expected := int(socket.get_meta(
				&"loot_capacity",
				DEFAULT_CAPACITY[socket.socket_type]
			))
			var actual := 0
			for socket_child: Node in socket.get_children():
				var item := socket_child as PickupItem
				if item == null or not item.is_in_group("runtime_loot"):
					continue
				actual += 1
				if (
					socket.socket_type in ["cabinet", "wardrobe", "fridge"]
					and not HouseLootSpawner.is_item_volume_clear(item)
				):
					failures.append("seed=%d %s clips storage" % [seed, item.get_path()])
			if actual != expected:
				failures.append("seed=%d type=%s source=%s supports=%s position=%s has %d/%d items" % [
					seed,
					socket.socket_type,
					socket.source_node,
					socket.support_nodes,
					socket.global_position,
					actual,
					expected,
				])
	if not failures.is_empty():
		for failure: String in failures:
			push_error("[LOOT_SEED_TEST] %s" % failure)
		quit(1)
		return
	print("[LOOT_SEED_TEST] PASS seeds=%d all openable storage populated" % SEEDS.size())
	quit()
