extends Node3D
class_name HeldItem

## Root script for an item's model_scene. While the item is in the player's hand
## it reads its own use input; the player only decides whether use is allowed
## right now. On the floor the same scene is the PickupItem's model, where its
## processing is disabled and it only reflects its state.

## Scale and rotate the model into the generic hand pose. Turn off for items
## with an authored first-person pose, such as guns.
@export var fit_to_hand := true
## Transform relative to the player's HeldItemPivot, used when fit_to_hand is off.
@export var hand_transform := Transform3D.IDENTITY

var player: Player
## Per-item state shared by reference with the inventory entry and PickupItem,
## so it survives slot switches, throws and pickups.
var state: Dictionary = {}
var use_input_armed := false


func apply_state(item_state: Dictionary) -> void:
	state = item_state
	_on_state_applied()


func equip(holder: Player, item_state: Dictionary) -> void:
	player = holder
	apply_state(item_state)
	_on_equipped()


func _process(delta: float) -> void:
	if player == null:
		return
	if not player.can_use_held_item():
		use_input_armed = false
		return
	# The click that selected this item or closed a dialogue must not also use it.
	if not use_input_armed:
		use_input_armed = (
			not Input.is_action_pressed("primary_attack")
			and not Input.is_action_pressed("secondary_attack")
		)
		return
	_process_use_input(delta)


## Override for continuous input such as hold-to-fire. By default each click
## calls the matching use callback once.
func _process_use_input(_delta: float) -> void:
	if Input.is_action_just_pressed("primary_attack"):
		_on_primary_use()
	if Input.is_action_just_pressed("secondary_attack"):
		_on_secondary_use()


func _on_primary_use() -> void:
	pass


func _on_secondary_use() -> void:
	pass


func _on_equipped() -> void:
	pass


## Called whenever state is (re)assigned or changed; update visuals from it here.
func _on_state_applied() -> void:
	pass
