extends RefCounted
class_name HouseLootSpawner

const PICKUP_ITEM_SCENE := preload("res://entity/item/PickupItem.tscn")
const ACCESS_TEST_DISTANCE := 1.2
const ACCESS_TEST_EYE_HEIGHT := 0.45
const ACCESS_PLACEMENT_ATTEMPTS := 16
const SHELF_OCCUPIED_SOCKET_COUNT := 18
const SHELF_DOUBLE_SOCKET_COUNT := 2
const SHELF_ITEM_BUDGET := SHELF_OCCUPIED_SOCKET_COUNT + SHELF_DOUBLE_SOCKET_COUNT
const CABINET_FIT_RATIO := 0.38
const WARDROBE_FIT_RATIO := 0.30
const FRIDGE_FIT_RATIO := 0.62
const LOOT_SEPARATION := 0.035
const CASH_MODELS := [
	preload("res://asset/model/loot_pack/cash_1.glb"),
	preload("res://asset/model/loot_pack/cash_1_2.glb"),
	preload("res://asset/model/loot_pack/cash_2.glb"),
	preload("res://asset/model/loot_pack/cash_2_1.glb"),
	preload("res://asset/model/loot_pack/cash_3.glb"),
	preload("res://asset/model/loot_pack/cash_3_1.glb"),
	preload("res://asset/model/loot_pack/cash_4.glb"),
	preload("res://asset/model/loot_pack/cash_5.glb"),
	preload("res://asset/model/loot_pack/cash_5_1.glb"),
	preload("res://asset/model/loot_pack/cash_6.glb"),
	preload("res://asset/model/loot_pack/cash_6_1.glb"),
]
const MEDICINE_BOTTLE_MODELS := [
	preload("res://asset/model/loot_pack/pills_bottle_1.glb"),
	preload("res://asset/model/loot_pack/pills_bottle_1_1.glb"),
	preload("res://asset/model/loot_pack/pills_bottle_1_2.glb"),
	preload("res://asset/model/loot_pack/pills_bottle_2.glb"),
	preload("res://asset/model/loot_pack/pills_bottle_2_1.glb"),
	preload("res://asset/model/loot_pack/pills_bottle_2_2.glb"),
]
const CANNED_FOOD_MODELS := [
	preload("res://asset/model/loot_pack/canned_food_mp_1.glb"),
	preload("res://asset/model/loot_pack/canned_food_mp_2.glb"),
	preload("res://asset/model/loot_pack/canned_food_mp_3.glb"),
	preload("res://asset/model/loot_pack/canned_food_mp_4.glb"),
	preload("res://asset/model/loot_pack/canned_food_mp_5_rusty.glb"),
]
const BOOK_MODELS := [
	preload("res://asset/model/loot_pack/book_mp_1.glb"),
	preload("res://asset/model/loot_pack/book_mp_2.glb"),
	preload("res://asset/model/loot_pack/book_mp_3.glb"),
	preload("res://asset/model/loot_pack/book_mp_4.glb"),
	preload("res://asset/model/loot_pack/book_mp_5.glb"),
	preload("res://asset/model/loot_pack/book_mp_6.glb"),
	preload("res://asset/model/loot_pack/book_mp_7.glb"),
	preload("res://asset/model/loot_pack/book_mp_8.glb"),
	preload("res://asset/model/loot_pack/book_mp_9.glb"),
	preload("res://asset/model/loot_pack/book_mp_10.glb"),
	preload("res://asset/model/loot_pack/open_book_mp_1.glb"),
]
const PHOTO_FRAME_MODELS := [
	preload("res://asset/model/loot_pack/photo_frame_mp_1.glb"),
	preload("res://asset/model/loot_pack/photo_frame_mp_2.glb"),
]
const CIGARETTE_MODELS := [
	preload("res://asset/model/items/models/cigs_carton.glb"),
	preload("res://asset/model/loot_pack/cigs_packet_1.glb"),
	preload("res://asset/model/loot_pack/cig_1.glb"),
	preload("res://asset/model/loot_pack/cig_2.glb"),
	preload("res://asset/model/loot_pack/cig_3.glb"),
]
const NOTEBOOK_MODELS := [
	preload("res://asset/model/items/models/ps1_notebook.glb"),
	preload("res://asset/model/loot_pack/notebook_1.glb"),
]
const CLOCK_MODELS := [
	preload("res://asset/model/loot_pack/clock_1.glb"),
	preload("res://asset/model/loot_pack/clock_2.glb"),
]
const CROSS_MODELS := [
	preload("res://asset/model/loot_pack/cross_1.glb"),
	preload("res://asset/model/loot_pack/cross_mp_2.glb"),
]
const LIGHTER_MODELS := [
	preload("res://asset/model/loot_pack/lighter_mp_1.glb"),
	preload("res://asset/model/loot_pack/lighter_mp_1_1.glb"),
	preload("res://asset/model/loot_pack/lighter_mp_1_2.glb"),
]
const MATCHBOX_MODELS := [
	preload("res://asset/model/loot_pack/matchbox_1.glb"),
	preload("res://asset/model/loot_pack/matchbox_2.glb"),
]
const GLASS_BOTTLE_MODELS := [
	preload("res://asset/model/loot_pack/glass_bottle_1.glb"),
	preload("res://asset/model/loot_pack/glass_bottle_2.glb"),
]
const CUTLERY_MODELS := [
	preload("res://asset/model/loot_pack/spoon_mp_1.glb"),
	preload("res://asset/model/loot_pack/fork_mp_1.glb"),
]
const WRITING_TOOL_MODELS := [
	preload("res://asset/model/loot_pack/pen_mp_1.glb"),
	preload("res://asset/model/loot_pack/pencil_mp_1.glb"),
]
const FLASHLIGHT_MODELS := [
	preload("res://asset/model/loot_pack/flashlight_1.glb"),
	preload("res://asset/model/loot_pack/flashlight_mp_1.glb"),
]
const BATTERY_MODELS := [
	preload("res://asset/model/loot_pack/battery_mp_1.glb"),
	preload("res://asset/model/loot_pack/battery_mp_1_1.glb"),
	preload("res://asset/model/loot_pack/battery_mp_2.glb"),
	preload("res://asset/model/loot_pack/battery_mp_2_1.glb"),
	preload("res://asset/model/loot_pack/battery_mp_3_1.glb"),
	preload("res://asset/model/loot_pack/battery_mp_3_2.glb"),
]
const LOOSE_PILL_MODELS := [
	preload("res://asset/model/loot_pack/pills_1.glb"),
	preload("res://asset/model/loot_pack/pills_2.glb"),
	preload("res://asset/model/loot_pack/pills_2_1.glb"),
	preload("res://asset/model/loot_pack/pills_2_2.glb"),
	preload("res://asset/model/loot_pack/pills_3.glb"),
]
const BANDAGE_MODELS := [
	preload("res://asset/model/loot_pack/bandage_mp_1.glb"),
	preload("res://asset/model/loot_pack/bandage_mp_2.glb"),
]
const SYRINGE_MODELS := [
	preload("res://asset/model/loot_pack/syringe_mp_1.glb"),
	preload("res://asset/model/loot_pack/syringe_mp_1_1.glb"),
]
const RAW_MEAT_MODELS := [
	preload("res://asset/model/loot_pack/meat_1.glb"),
	preload("res://asset/model/loot_pack/meat_1_1.glb"),
]
const LOLLIPOP_MODELS := [
	preload("res://asset/model/loot_pack/lollipop_mp_1.glb"),
	preload("res://asset/model/loot_pack/lollipop_mp_1_1.glb"),
	preload("res://asset/model/loot_pack/lollipop_mp_1_2.glb"),
	preload("res://asset/model/loot_pack/lollipop_mp_1_3.glb"),
]
const SCREWDRIVER_MODELS := [
	preload("res://asset/model/loot_pack/screwdriver_mp_1.glb"),
	preload("res://asset/model/loot_pack/screwdriver_mp_1_1.glb"),
	preload("res://asset/model/loot_pack/screwdriver_mp_1_2.glb"),
	preload("res://asset/model/loot_pack/screwdriver_mp_2.glb"),
	preload("res://asset/model/loot_pack/screwdriver_mp_2_1.glb"),
	preload("res://asset/model/loot_pack/screwdriver_mp_2_2.glb"),
]
const NAIL_MODELS := [
	preload("res://asset/model/loot_pack/nails_1.glb"),
	preload("res://asset/model/loot_pack/nails_1_rusty.glb"),
]
const RUSTY_TIN_MODELS := [
	preload("res://asset/model/loot_pack/tin_can_mp_1_rusty.glb"),
	preload("res://asset/model/loot_pack/tin_can_mp_1_rusty_1.glb"),
]
const SPONGE_MODELS := [
	preload("res://asset/model/loot_pack/sponge_mp_1.glb"),
	preload("res://asset/model/loot_pack/sponge_mp_2.glb"),
]
const POTTED_PLANT_MODELS := [
	preload("res://asset/model/loot_pack/planter_pot_mp_1_full.glb"),
	preload("res://asset/model/loot_pack/potted_cactus_mp_1.glb"),
]
const LOOT_DEFINITIONS := {
	&"cash": {
		"name": "Cash",
		"models": CASH_MODELS,
		"icon_path": "res://asset/ui/loot_icons/cash.png",
		"mass": 0.15,
	},
	&"coins": {
		"name": "Coins",
		"model": preload("res://asset/model/loot_pack/coin_mp_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/coins.png",
		"mass": 0.2,
	},
	&"pills": {
		"name": "Medicine Bottle",
		"models": MEDICINE_BOTTLE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/pills.png",
		"mass": 0.2,
	},
	&"canned_food": {
		"name": "Canned Food",
		"models": CANNED_FOOD_MODELS,
		"icon_path": "res://asset/ui/loot_icons/canned_food.png",
		"mass": 0.45,
	},
	&"book": {
		"name": "Book",
		"models": BOOK_MODELS,
		"icon_path": "res://asset/ui/loot_icons/book.png",
		"mass": 0.55,
	},
	&"photo_frame": {
		"name": "Photo Frame",
		"models": PHOTO_FRAME_MODELS,
		"icon_path": "res://asset/ui/loot_icons/photo_frame.png",
		"mass": 0.4,
	},
	&"painting": {
		"name": "Painting",
		"model": preload("res://asset/model/loot_pack/painting_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/painting.png",
		"mass": 0.7,
	},
	&"gold_bar": {
		"name": "Gold Bar",
		"model": preload("res://asset/model/loot_pack/gold_bar_pcs_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/gold_bar.png",
		"mass": 1.8,
	},
	&"cigarettes": {
		"name": "Cigarettes",
		"models": CIGARETTE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/cigarettes.png",
		"display_size": 0.48,
		"mass": 0.2,
	},
	&"notebook": {
		"name": "Notebook",
		"models": NOTEBOOK_MODELS,
		"icon_path": "res://asset/ui/loot_icons/notebook.png",
		"display_size": 0.5,
		"mass": 0.35,
	},
	&"antique_radio": {
		"name": "Antique Radio",
		"model": preload("res://asset/model/items/models/ps1_antique_radio.glb"),
		"icon_path": "res://asset/ui/loot_icons/antique_radio.png",
		"display_size": 0.62,
		"mass": 3.0,
	},
	&"bankers_lamp": {
		"name": "Banker's Lamp",
		"model": preload("res://asset/model/items/models/ps1_brass_bankers_desk_lamp.glb"),
		"icon_path": "res://asset/ui/loot_icons/bankers_lamp.png",
		"display_size": 0.65,
		"mass": 2.2,
	},
	&"clock": {
		"name": "Clock",
		"models": CLOCK_MODELS,
		"icon_path": "res://asset/ui/loot_icons/clock.png",
		"display_size": 0.46,
		"mass": 0.8,
	},
	&"cross": {
		"name": "Crucifix",
		"models": CROSS_MODELS,
		"icon_path": "res://asset/ui/loot_icons/cross.png",
		"display_size": 0.38,
		"mass": 0.25,
	},
	&"ashtray": {
		"name": "Ashtray",
		"model": preload("res://asset/model/loot_pack/ashtray_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/ashtray.png",
		"display_size": 0.34,
		"mass": 0.45,
	},
	&"lighter": {
		"name": "Lighter",
		"models": LIGHTER_MODELS,
		"icon_path": "res://asset/ui/loot_icons/lighter.png",
		"display_size": 0.24,
		"mass": 0.08,
	},
	&"matches": {
		"name": "Matches",
		"models": MATCHBOX_MODELS,
		"icon_path": "res://asset/ui/loot_icons/matches.png",
		"display_size": 0.25,
		"mass": 0.06,
	},
	&"glass_bottle": {
		"name": "Glass Bottle",
		"models": GLASS_BOTTLE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/glass_bottle.png",
		"display_size": 0.48,
		"mass": 0.55,
	},
	&"plate": {
		"name": "Plate",
		"model": preload("res://asset/model/loot_pack/plate_mp_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/plate.png",
		"display_size": 0.40,
		"mass": 0.45,
	},
	&"cutlery": {
		"name": "Cutlery",
		"models": CUTLERY_MODELS,
		"icon_path": "res://asset/ui/loot_icons/cutlery.png",
		"display_size": 0.34,
		"mass": 0.12,
	},
	&"writing_tools": {
		"name": "Writing Tool",
		"models": WRITING_TOOL_MODELS,
		"icon_path": "res://asset/ui/loot_icons/writing_tools.png",
		"display_size": 0.32,
		"mass": 0.05,
	},
	&"magnet": {
		"name": "Magnet",
		"model": preload("res://asset/model/loot_pack/magnet_mp_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/magnet.png",
		"display_size": 0.24,
		"mass": 0.08,
	},
	&"flashlight": {
		"name": "Flashlight",
		"models": FLASHLIGHT_MODELS,
		"icon_path": "res://asset/ui/loot_icons/flashlight.png",
		"display_size": 0.44,
		"mass": 0.5,
	},
	&"battery": {
		"name": "Battery",
		"models": BATTERY_MODELS,
		"icon_path": "res://asset/ui/loot_icons/battery.png",
		"display_size": 0.28,
		"mass": 0.2,
	},
	&"medicine_packet": {
		"name": "Medicine Packet",
		"model": preload("res://asset/model/loot_pack/pills_packet_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/medicine_packet.png",
		"display_size": 0.30,
		"mass": 0.08,
	},
	&"loose_pills": {
		"name": "Loose Pills",
		"models": LOOSE_PILL_MODELS,
		"icon_path": "res://asset/ui/loot_icons/loose_pills.png",
		"display_size": 0.24,
		"mass": 0.04,
	},
	&"bandage": {
		"name": "Bandage",
		"models": BANDAGE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/bandage.png",
		"display_size": 0.32,
		"mass": 0.12,
	},
	&"syringe": {
		"name": "Syringe",
		"models": SYRINGE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/syringe.png",
		"display_size": 0.34,
		"mass": 0.08,
	},
	&"raw_meat": {
		"name": "Raw Meat",
		"models": RAW_MEAT_MODELS,
		"icon_path": "res://asset/ui/loot_icons/raw_meat.png",
		"display_size": 0.50,
		"mass": 0.8,
	},
	&"lollipop": {
		"name": "Lollipop",
		"models": LOLLIPOP_MODELS,
		"icon_path": "res://asset/ui/loot_icons/lollipop.png",
		"display_size": 0.28,
		"mass": 0.05,
	},
	&"kitchen_knife": {
		"name": "Kitchen Knife",
		"model": preload("res://asset/model/loot_pack/butcher_knife_mp_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/kitchen_knife.png",
		"display_size": 0.50,
		"mass": 0.55,
	},
	&"hand_saw": {
		"name": "Hand Saw",
		"model": preload("res://asset/model/loot_pack/hand_saw_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/hand_saw.png",
		"display_size": 0.58,
		"mass": 0.9,
	},
	&"screwdriver": {
		"name": "Screwdriver",
		"models": SCREWDRIVER_MODELS,
		"icon_path": "res://asset/ui/loot_icons/screwdriver.png",
		"display_size": 0.42,
		"mass": 0.25,
	},
	&"nails": {
		"name": "Nails",
		"models": NAIL_MODELS,
		"icon_path": "res://asset/ui/loot_icons/nails.png",
		"display_size": 0.28,
		"mass": 0.25,
	},
	&"rusty_tin": {
		"name": "Rusty Tin",
		"models": RUSTY_TIN_MODELS,
		"icon_path": "res://asset/ui/loot_icons/rusty_tin.png",
		"display_size": 0.38,
		"mass": 0.25,
	},
	&"fish_bones": {
		"name": "Fish Bones",
		"model": preload("res://asset/model/loot_pack/fish_skeleton_mp_1.glb"),
		"icon_path": "res://asset/ui/loot_icons/fish_bones.png",
		"display_size": 0.38,
		"mass": 0.1,
	},
	&"sponge": {
		"name": "Sponge",
		"models": SPONGE_MODELS,
		"icon_path": "res://asset/ui/loot_icons/sponge.png",
		"display_size": 0.34,
		"mass": 0.08,
	},
	&"potted_plant": {
		"name": "Potted Plant",
		"models": POTTED_PLANT_MODELS,
		"icon_path": "res://asset/ui/loot_icons/potted_plant.png",
		"display_size": 0.54,
		"mass": 1.1,
	},
}
const LOOT_IDS_BY_SOCKET_TYPE := {
	"drawer": [
		&"cash", &"coins", &"pills", &"cigarettes", &"notebook", &"gold_bar",
		&"cross", &"lighter", &"matches", &"writing_tools", &"magnet", &"battery",
		&"medicine_packet", &"loose_pills", &"bandage", &"syringe", &"lollipop",
		&"screwdriver",
	],
	"cabinet": [
		&"cutlery", &"kitchen_knife", &"hand_saw", &"nails", &"sponge", &"canned_food",
		&"ashtray", &"glass_bottle", &"plate", &"battery", &"medicine_packet",
		&"bandage", &"syringe", &"screwdriver",
	],
	"wardrobe": [
		&"cash", &"book", &"photo_frame", &"painting", &"cigarettes", &"gold_bar",
		&"cross", &"clock",
	],
	"fridge": [
		&"canned_food", &"canned_food", &"canned_food", &"raw_meat", &"raw_meat",
		&"glass_bottle", &"rusty_tin", &"fish_bones",
	],
	"shelf": [
		&"book", &"photo_frame", &"painting", &"pills", &"canned_food", &"notebook",
		&"cigarettes", &"antique_radio", &"clock", &"cross", &"ashtray", &"matches",
		&"glass_bottle", &"plate", &"writing_tools", &"flashlight", &"battery",
		&"lollipop", &"potted_plant", &"bankers_lamp",
	],
	"table": [
		&"book", &"photo_frame", &"cash", &"coins", &"pills", &"notebook",
		&"cigarettes", &"antique_radio", &"bankers_lamp", &"clock", &"ashtray",
		&"plate", &"writing_tools", &"potted_plant",
	],
}


static func spawn_for_house(house: Node3D) -> int:
	var sockets: Array[Node] = []
	for child: Node in house.get_tree().get_nodes_in_group("loot_socket"):
		var socket := child as LootSocket
		if socket != null and house.is_ancestor_of(socket):
			sockets.append(socket)
	var configured_seed := int(ProjectSettings.get_setting(
		"thief_horror/runtime_loot_seed",
		-1
	))
	var session_seed := Time.get_ticks_usec() if configured_seed < 0 else configured_seed
	return spawn_for_sockets(sockets, session_seed, true)


static func spawn_for_sockets(
	sockets: Array,
	session_seed := 0,
	require_clear_approach := false
) -> int:
	var spawned_count := 0
	var choice_cursors := {}
	var shelf_spawned_count := 0
	var shelf_occupied_count := 0
	for child: Node in _ordered_loot_sockets(sockets, session_seed):
		var socket := child as LootSocket
		if socket == null:
			continue
		var choices: Array = LOOT_IDS_BY_SOCKET_TYPE.get(socket.socket_type, [])
		if choices.is_empty():
			continue
		var random := RandomNumberGenerator.new()
		random.seed = absi(hash(String(socket.get_path())) ^ int(session_seed))
		if not choice_cursors.has(socket.socket_type):
			choice_cursors[socket.socket_type] = (
				absi(hash(socket.socket_type) ^ int(session_seed)) % choices.size()
			)
		var item_count := _item_count_for_storage_socket(socket)
		if socket.socket_type == "shelf":
			var remaining_items := SHELF_ITEM_BUDGET - shelf_spawned_count
			if remaining_items <= 0:
				continue
			var remaining_occupied := maxi(
				0,
				SHELF_OCCUPIED_SOCKET_COUNT - shelf_occupied_count
			)
			var extra_items := maxi(0, remaining_items - remaining_occupied)
			item_count = mini(remaining_items, 2 if extra_items > 0 else 1)
		var socket_spawned_count := 0
		for item_index in item_count:
			var choice_cursor := int(choice_cursors[socket.socket_type])
			var item: PickupItem
			var accepted_choice_cursor := choice_cursor
			for choice_offset in choices.size() * 2:
				var candidate_cursor := choice_cursor + choice_offset
				var loot_id := choices[candidate_cursor % choices.size()] as StringName
				item = _instantiate_loot_item(
					loot_id,
					socket,
					random,
					spawned_count
				)
				if _place_item_for_socket(
					item,
					socket,
					random,
					item_index,
					item_count,
					require_clear_approach
				):
					accepted_choice_cursor = candidate_cursor
					break
				item.free()
				item = null
			if item == null:
				continue
			item.attach_to_parent_support()
			item.add_to_group("runtime_loot")
			item.set_meta("loot_socket", socket.get_path())
			choice_cursors[socket.socket_type] = accepted_choice_cursor + 1
			spawned_count += 1
			socket_spawned_count += 1
		if socket.socket_type == "shelf" and socket_spawned_count > 0:
			shelf_spawned_count += socket_spawned_count
			shelf_occupied_count += 1
	return spawned_count


static func _instantiate_loot_item(
	loot_id: StringName,
	socket: LootSocket,
	random: RandomNumberGenerator,
	spawned_count: int
) -> PickupItem:
	var definition: Dictionary = LOOT_DEFINITIONS[loot_id]
	var item := PICKUP_ITEM_SCENE.instantiate() as PickupItem
	item.name = "Loot_%s_%03d" % [String(loot_id).capitalize(), spawned_count]
	item.item_id = loot_id
	item.display_name = String(definition.name)
	item.item_kind = &"item"
	item.model_scene = _choose_model(definition, random)
	item.icon = load(String(definition.icon_path)) as Texture2D
	item.display_size = float(definition.get("display_size", 1.0))
	item.fit_size_limit = socket.max_item_size
	if socket.socket_type in ["cabinet", "wardrobe", "fridge"]:
		var fit_ratio := _storage_fit_ratio(socket.socket_type)
		item.fit_size_limit.x *= fit_ratio
		item.fit_size_limit.z *= fit_ratio
	item.item_mass = float(definition.mass)
	item.freeze = true
	item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	item.rotation.y = random.randf_range(-PI, PI)
	socket.add_child(item)
	return item


static func _place_item_for_socket(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator,
	item_index: int,
	item_count: int,
	require_clear_approach: bool
) -> bool:
	if socket.socket_type == "shelf":
		return _place_shelf_item(item, socket, random, require_clear_approach)
	if socket.socket_type in ["cabinet", "wardrobe", "fridge"]:
		return _place_storage_item(item, socket, random, item_index, item_count)
	if socket.socket_type == "table":
		return _place_table_item(item, socket, random, require_clear_approach)
	item.place_on_local_support(socket.placement_size, random)
	if socket.socket_type == "drawer":
		_bias_toward_drawer_opening(item, socket, random)
	return true


static func _choose_model(
	definition: Dictionary,
	random: RandomNumberGenerator
) -> PackedScene:
	var models: Array = definition.get("models", [])
	if not models.is_empty():
		return models[random.randi_range(0, models.size() - 1)] as PackedScene
	return definition.get("model") as PackedScene


static func _item_count_for_storage_socket(socket: LootSocket) -> int:
	if socket.has_meta(&"loot_capacity"):
		return int(socket.get_meta(&"loot_capacity"))
	match socket.socket_type:
		"cabinet", "fridge":
			return 2
		"wardrobe":
			return 4
		_:
			return 1


static func _ordered_loot_sockets(sockets: Array, session_seed: int) -> Array:
	var result: Array = []
	var shelves: Array[LootSocket] = []
	for child: Node in sockets:
		var socket := child as LootSocket
		if socket == null:
			continue
		if socket.socket_type == "shelf":
			shelves.append(socket)
		else:
			result.append(socket)
	var random := RandomNumberGenerator.new()
	random.seed = absi(hash("shelf_positions") ^ session_seed)
	for index in range(shelves.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary := shelves[index]
		shelves[index] = shelves[swap_index]
		shelves[swap_index] = temporary
	result.append_array(shelves)
	return result


static func _place_shelf_item(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator,
	require_clear_approach: bool
) -> bool:
	for _attempt in ACCESS_PLACEMENT_ATTEMPTS:
		item.place_on_local_support(socket.placement_size, random)
		_bias_away_from_shelf_center(item, socket, random)
		if not _ground_to_mesh_support(item, socket):
			continue
		if not is_item_volume_clear(item):
			continue
		if _overlaps_socket_loot(item, socket):
			continue
		if not require_clear_approach or _has_clear_world_approach(item):
			return true
	return false


static func _place_storage_item(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator,
	item_index: int,
	item_count: int
) -> bool:
	for _attempt in ACCESS_PLACEMENT_ATTEMPTS:
		item.place_on_local_support(socket.placement_size, random)
		var footprint := _item_footprint(item)
		var x_limit := maxf(
			0.0,
			(socket.placement_size.x - footprint.x) * 0.48
		)
		var z_limit := maxf(
			0.0,
			(socket.placement_size.z - footprint.y) * 0.48
		)
		if item_count >= 4:
			item.position.x = (-1.0 if item_index % 2 == 0 else 1.0) * x_limit * (
				random.randf_range(0.55, 0.70)
			)
			# Keep the second wardrobe row near the opening plane. A row at the
			# opposite depth sits behind the swept-open doors in the tall closets.
			item.position.z = (-1.0 if item_index < 2 else 0.0) * z_limit * (
				random.randf_range(0.55, 0.75)
			)
		elif socket.socket_type == "cabinet" and socket.has_meta(&"storage_inward_world"):
			var inward_world := socket.get_meta(&"storage_inward_world") as Vector3
			var inward_local := socket.global_basis.inverse() * inward_world
			inward_local.y = 0.0
			inward_local = inward_local.normalized()
			var lateral_local := Vector3(-inward_local.z, 0.0, inward_local.x)
			var lateral_limit := INF
			if absf(lateral_local.x) > 0.001:
				lateral_limit = minf(lateral_limit, x_limit / absf(lateral_local.x))
			if absf(lateral_local.z) > 0.001:
				lateral_limit = minf(lateral_limit, z_limit / absf(lateral_local.z))
			if is_inf(lateral_limit):
				lateral_limit = 0.0
			var side := -1.0 if item_index % 2 == 0 else 1.0
			var lateral_offset := (
				0.0
				if item_count == 1
				else side * lateral_limit * random.randf_range(0.75, 0.90)
			)
			item.position.x = lateral_local.x * lateral_offset
			item.position.z = lateral_local.z * lateral_offset
		elif socket.placement_size.x >= socket.placement_size.z:
			item.position.x = (-1.0 if item_index % 2 == 0 else 1.0) * x_limit * (
				random.randf_range(0.72, 0.88) if item_count > 1
				else random.randf_range(0.40, 0.58)
			)
		else:
			item.position.z = (-1.0 if item_index % 2 == 0 else 1.0) * z_limit * (
				random.randf_range(0.72, 0.88) if item_count > 1
				else random.randf_range(0.40, 0.58)
			)
		if socket.socket_type == "fridge":
			if not _ground_to_mesh_support(item, socket):
				continue
		else:
			_ground_to_world_support(item)
		if not is_item_volume_clear(item):
			continue
		if not _overlaps_socket_loot(item, socket):
			return true
	return false


static func _storage_fit_ratio(socket_type: String) -> float:
	match socket_type:
		"wardrobe":
			return WARDROBE_FIT_RATIO
		"fridge":
			return FRIDGE_FIT_RATIO
		_:
			return CABINET_FIT_RATIO


static func _bias_away_from_shelf_center(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator
) -> void:
	var footprint := _item_footprint(item)
	var x_room := maxf(0.0, socket.placement_size.x - footprint.x) * 0.42
	var z_room := maxf(0.0, socket.placement_size.z - footprint.y) * 0.42
	if x_room >= z_room and x_room > 0.01:
		item.position.x = (-1.0 if random.randf() < 0.5 else 1.0) * random.randf_range(
			x_room * 0.28,
			x_room
		)
	elif z_room > 0.01:
		item.position.z = (-1.0 if random.randf() < 0.5 else 1.0) * random.randf_range(
			z_room * 0.28,
			z_room
		)


static func _overlaps_socket_loot(item: PickupItem, socket: LootSocket) -> bool:
	var footprint := _item_footprint(item)
	for child: Node in socket.get_children():
		var other := child as PickupItem
		if other == null or other == item:
			continue
		var other_footprint := _item_footprint(other)
		if (
			absf(item.position.x - other.position.x)
			< (footprint.x + other_footprint.x) * 0.5 + LOOT_SEPARATION
			and absf(item.position.z - other.position.z)
			< (footprint.y + other_footprint.y) * 0.5 + LOOT_SEPARATION
		):
			return true
	return false


static func _item_footprint(item: PickupItem) -> Vector2:
	var yaw := item.rotation.y
	return Vector2(
		absf(cos(yaw)) * item.actual_normalized_size.x
		+ absf(sin(yaw)) * item.actual_normalized_size.z,
		absf(sin(yaw)) * item.actual_normalized_size.x
		+ absf(cos(yaw)) * item.actual_normalized_size.z
	)


static func _bias_toward_drawer_opening(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator
) -> void:
	var drawer := socket.get_parent() as SlidingInteractable
	if drawer == null:
		return
	var outward_world := drawer.slide_axis_world * drawer.open_direction
	var outward_local := (drawer.global_basis.inverse() * outward_world).normalized()
	var yaw := item.rotation.y
	var footprint_x := (
		absf(cos(yaw)) * item.actual_normalized_size.x
		+ absf(sin(yaw)) * item.actual_normalized_size.z
	)
	var footprint_z := (
		absf(sin(yaw)) * item.actual_normalized_size.x
		+ absf(cos(yaw)) * item.actual_normalized_size.z
	)
	if absf(outward_local.x) >= absf(outward_local.z):
		var x_room := maxf(0.0, socket.placement_size.x - footprint_x) * 0.42
		item.position.x = signf(outward_local.x) * random.randf_range(
			x_room * 0.45,
			x_room * 0.85
		)
	else:
		var z_room := maxf(0.0, socket.placement_size.z - footprint_z) * 0.42
		item.position.z = signf(outward_local.z) * random.randf_range(
			z_room * 0.45,
			z_room * 0.85
		)


static func _ground_to_world_support(item: PickupItem) -> void:
	var visible_bottom := item.global_position.y - item.actual_normalized_size.y * 0.5
	var ray_start := Vector3(
		item.global_position.x,
		visible_bottom + 0.06,
		item.global_position.z
	)
	var ray_end := ray_start - Vector3.UP * 1.4
	var excluded_rids: Array[RID] = []
	for child: Node in item.get_tree().get_nodes_in_group("interactable"):
		if child is MovingInteractable:
			excluded_rids.append((child as MovingInteractable).get_rid())
	var hit := _find_upward_support(item, ray_start, ray_end, excluded_rids)
	if hit.is_empty():
		return
	var support_y := (hit.position as Vector3).y
	# A lower shelf or drawer is not the intended support. Keep the authored
	# socket height instead of dropping loot into another compartment.
	if visible_bottom - support_y > 0.28:
		return
	item.global_position.y += support_y + 0.003 - visible_bottom
	item.set_meta("ground_support_y", support_y)


static func _find_upward_support(
	item: PickupItem,
	ray_start: Vector3,
	ray_end: Vector3,
	excluded_rids: Array[RID]
) -> Dictionary:
	var current_start := ray_start
	for _attempt in 10:
		var query := PhysicsRayQueryParameters3D.create(
			current_start,
			ray_end,
			1,
			excluded_rids
		)
		var hit := item.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		if (hit.normal as Vector3).dot(Vector3.UP) >= 0.55:
			return hit
		var hit_position := hit.position as Vector3
		if hit_position.y <= ray_end.y + 0.005:
			return {}
		current_start = hit_position - Vector3.UP * 0.005
	return {}


static func _place_table_item(
	item: PickupItem,
	socket: LootSocket,
	random: RandomNumberGenerator,
	require_clear_approach: bool
) -> bool:
	for attempt in ACCESS_PLACEMENT_ATTEMPTS:
		if attempt > 0:
			item.place_on_local_support(socket.placement_size, random)
		if not _ground_to_mesh_support(item, socket):
			continue
		if not is_item_volume_clear(item):
			continue
		if not require_clear_approach or _has_clear_world_approach(item):
			return true
	return false


static func _ground_to_mesh_support(item: PickupItem, socket: LootSocket) -> bool:
	var support_y := find_item_mesh_support_y(socket, item)
	if is_nan(support_y):
		return false
	var visible_bottom := item.global_position.y - item.actual_normalized_size.y * 0.5
	item.global_position.y += support_y + PickupItem.SUPPORT_CLEARANCE - visible_bottom
	item.set_meta("mesh_support_y", support_y)
	return true


static func find_item_mesh_support_y(socket: LootSocket, item: PickupItem) -> float:
	var axis_x := item.global_basis.x.normalized()
	var axis_z := item.global_basis.z.normalized()
	var half_x := item.actual_normalized_size.x * 0.38
	var half_z := item.actual_normalized_size.z * 0.38
	var offsets := [
		Vector3.ZERO,
		axis_x * half_x + axis_z * half_z,
		axis_x * half_x - axis_z * half_z,
		-axis_x * half_x + axis_z * half_z,
		-axis_x * half_x - axis_z * half_z,
	]
	var highest_y := -INF
	var lowest_y := INF
	for offset: Vector3 in offsets:
		var support_y := find_mesh_support_y(socket, item.global_position + offset)
		if is_nan(support_y):
			return NAN
		highest_y = maxf(highest_y, support_y)
		lowest_y = minf(lowest_y, support_y)
	# Loot is authored upright. Reject placements that bridge trim, slopes, or
	# multiple levels instead of pretending the center point is enough support.
	if highest_y - lowest_y > 0.02:
		return NAN
	return highest_y


static func is_item_volume_clear(item: PickupItem) -> bool:
	if not item.is_inside_tree():
		return false
	# Test the occupied core rather than only the center point. The shorter Y
	# extent deliberately clears the supporting shelf while still catching side,
	# back, trim, and closed-door penetration.
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(0.01, item.actual_normalized_size.x * 0.90),
		maxf(0.002, item.actual_normalized_size.y * 0.72),
		maxf(0.01, item.actual_normalized_size.z * 0.90)
	)
	shape.margin = 0.001
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = item.global_transform
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return item.get_world_3d().direct_space_state.intersect_shape(query, 16).is_empty()


static func find_mesh_support_y(socket: LootSocket, world_position: Vector3) -> float:
	var source := socket.get_node_or_null(socket.source_node) as MeshInstance3D
	if source == null or source.mesh == null:
		return NAN
	var expected_y := socket.global_position.y
	var best_y := NAN
	var best_distance := INF
	var point := Vector2(world_position.x, world_position.z)
	for surface_index in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in triangle_count:
			var ia := indices[triangle_index * 3] if not indices.is_empty() else triangle_index * 3
			var ib := indices[triangle_index * 3 + 1] if not indices.is_empty() else triangle_index * 3 + 1
			var ic := indices[triangle_index * 3 + 2] if not indices.is_empty() else triangle_index * 3 + 2
			var a := source.to_global(vertices[ia])
			var b := source.to_global(vertices[ib])
			var c := source.to_global(vertices[ic])
			var cross := (b - a).cross(c - a)
			if cross.length_squared() < 0.000001 or absf(cross.normalized().y) < 0.65:
				continue
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			var c2 := Vector2(c.x, c.z)
			var denominator := (
				(b2.y - c2.y) * (a2.x - c2.x)
				+ (c2.x - b2.x) * (a2.y - c2.y)
			)
			if absf(denominator) < 0.000001:
				continue
			var weight_a := (
				(b2.y - c2.y) * (point.x - c2.x)
				+ (c2.x - b2.x) * (point.y - c2.y)
			) / denominator
			var weight_b := (
				(c2.y - a2.y) * (point.x - c2.x)
				+ (a2.x - c2.x) * (point.y - c2.y)
			) / denominator
			var weight_c := 1.0 - weight_a - weight_b
			if weight_a < -0.001 or weight_b < -0.001 or weight_c < -0.001:
				continue
			var surface_y := weight_a * a.y + weight_b * b.y + weight_c * c.y
			var distance := absf(surface_y - expected_y)
			if distance <= 0.045 and distance < best_distance:
				best_distance = distance
				best_y = surface_y
	return best_y


static func _has_clear_world_approach(item: PickupItem) -> bool:
	if not item.is_inside_tree():
		return false
	var target := item.global_position
	var directions := [
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		(Vector3.FORWARD + Vector3.LEFT).normalized(),
		(Vector3.FORWARD + Vector3.RIGHT).normalized(),
		(Vector3.BACK + Vector3.LEFT).normalized(),
		(Vector3.BACK + Vector3.RIGHT).normalized(),
	]
	for direction: Vector3 in directions:
		var ray_start := (
			target
			+ direction * ACCESS_TEST_DISTANCE
			+ Vector3.UP * ACCESS_TEST_EYE_HEIGHT
		)
		var query := PhysicsRayQueryParameters3D.create(ray_start, target, 1)
		var hit := item.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
	return false
