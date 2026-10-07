extends CharacterBody3D
class_name Player

@export var aim_ray_prefab: PackedScene
@export_range(0.0, 0.6, 0.05) var max_step_height := 0.35
@export_range(-89.0, 89.0, 0.1) var initial_camera_pitch_degrees := 0.0
## Item scenes the player starts with, in hotbar order.
@export var initial_items: Array[PackedScene] = []

@onready var player_camera: ShakeableCamera = $Neck/ShakeableCamera
@onready var debug_label: Label = $Neck/ShakeableCamera/DebugLabel
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var neck: Node3D = $Neck
@onready var state_chart: StateChart = $StateChart
@onready var standing_collision: CollisionShape3D = $StandingCollision
@onready var crouching_collision: CollisionShape3D = $CrouchingCollision
@onready var audio_player: CharacterAudioPlayer3D = $CharacterAudioPlayer3D

@onready var held_item_pivot: Node3D = $Neck/ShakeableCamera/HeldItemPivot
@onready var aim_ray: AimRay = $Neck/ShakeableCamera/AimRay
@onready var aim_reticle: TextureRect = $Neck/ShakeableCamera/AimRecticle
@onready var hitmarker: TextureRect = $Neck/ShakeableCamera/HitMarker
@onready var pause_ui: PauseUI = $CanvasLayer/PauseUI
@onready var hotbar: HotbarUI = $CanvasLayer/Hotbar

var landing_sfx = preload("res://asset/sfx/player/jump_landing.wav")
# Guns whose shot effects are pooled before gameplay starts.
var prewarmed_gun_scenes: Array[PackedScene] = [
	preload("res://entity/weapon/gun/StarterPistol.tscn"),
]
var interaction_outline_shader = preload("res://material/interaction_outline.gdshader")

const WALK_SPEED = 1.5
const JUMP_FORCE = 5.0

const MAX_FALL_SPEED = 50.0
const ACCEL_RATE = 40.0
const GRAVITY = 14
const FALL_SPEED_TO_SHAKE_CAMERA = 15
const HEAVY_FALL_SHAKE_TRAUMA = 0.8
const RECOIL_COEFFICIENT = 10
const HITSCAN_COLLISION_MASK = 3
const HITSCAN_SURFACE_OFFSET = 0.01
const STUCK_LOG_INTERVAL_MSEC = 500
const STUCK_MIN_REQUEST_DISTANCE = 0.005
const STUCK_PROGRESS_RATIO = 0.15
const BLOCKED_JUMP_MOTION_EPSILON = 0.001
const AIRBORNE_WEDGE_RECOVERY_FRAMES = 6
const AIRBORNE_WEDGE_MOTION_EPSILON = 0.001
const AIRBORNE_WEDGE_MIN_HEIGHT = 0.05
const INVENTORY_SIZE := 5
const INTERACTION_DISTANCE := 3.2
const INTERACTION_COLLISION_MASK := 1 | 8 # World/interactables and dropped items.
const THROW_SPEED := 7.0
const THROW_SPAWN_DISTANCE := 0.8
const OUTLINE_VISIBILITY_MASK := 1 << 19
const FOOTSTEP_SURFACE_MASK := (1 << 0) | (1 << 4)
const FOOTSTEP_MIN_DISTANCE := 0.95
const FOOTSTEP_MAX_DISTANCE := 1.15
const LADDER_SNAP_RATE := 10.0
const LADDER_JUMP_OFF_MULTIPLIER := 0.6
const LADDER_JUMP_OFF_SPEED := 3.0
const LADDER_MANTLE_SPEED := 2.0
const LADDER_MANTLE_CLEARANCE := 0.05
# Grabbing from a floor this close to the ladder top climbs over onto it.
const LADDER_TOP_ENTRY_MARGIN := 0.5
const LADDER_RUNG_SOUND_DISTANCE := 0.45

const CROUCH_SPEED_MODIFIER = 0.5
const SPRINT_SPEED_MODIFIER = 2.5

var jumped = false
var can_coyote_jump = false
var vel_horizontal = Vector2(0, 0)
var vel_vertical = 0
var is_sprinting = false
var is_crouching := false:
	set(value):
		is_crouching = value
		if is_node_ready():
			_apply_crouch_collision()
var raw_input_dir = Vector2(0, 0)
var input_dir = Vector2(0, 0)
var held_item_pivot_original_pos: Vector3
var hitscan_pools: Dictionary = {}
var particle_pools: Dictionary = {}
var shot_assets_ready := false
var landing_sfx_armed := false
var is_step_traversing := false
var step_debug_reason := "idle"
var last_stuck_log_msec := 0
## Items the player carries; null for an empty slot. Only the selected item
## is in the scene tree, as a child of held_item_pivot.
var inventory: Array[Item] = []
var selected_item_slot := 0
var focused_interactable: Node3D
var dev_probe_message := ""
var dev_probe_message_until_msec := 0
var outline_viewport: SubViewport
var outline_camera: Camera3D
var outline_rect: TextureRect
var jump_recovery_position := Vector3.ZERO
var jump_recovery_valid := false
var airborne_wedge_frames := 0
var dialogue_active := false
var preview_mode := false
# Neck offset relative to the body. The neck is placed manually every frame so
# the view follows the interpolated body position but the live mouse yaw.
var neck_offset_y := 0.0
var neck_tilt := 0.0
var footstep_distance_traveled := 0.525
var next_footstep_distance := 1.05
var current_ladder: Ladder
# Horizontal direction from the ladder's rails toward the climbing player.
var ladder_normal := Vector3.ZERO
var ladder_mantle_active := false
var ladder_mantle_target := Vector3.ZERO
var ladder_mantle_leaves := false
var ladder_rung_distance := 0.0

func _notification(what: int) -> void:
	# Stored items are outside the scene tree, so nothing else frees them.
	if what == NOTIFICATION_PREDELETE:
		for item in inventory:
			if item != null and not item.is_inside_tree():
				item.free()


func _ready():
	# Editor-only placeholder capsule; hide it in-game.
	$MeshInstance3D.visible = false
	_apply_crouch_collision()
	GameManager.player = self
	player_camera.set_fov(GameManager.camera_fov)
	player_camera.rotation_degrees.x = initial_camera_pitch_degrees
	if not GameManager.is_preparing_first_level:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	held_item_pivot_original_pos = held_item_pivot.position
	for index in INVENTORY_SIZE:
		inventory.append(null)
	_fill_initial_inventory()
	hotbar.update_slots(inventory, selected_item_slot)
	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	dialogue_manager.dialogue_started.connect(_on_dialogue_started)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	_refresh_held_item()
	_setup_interaction_outline_overlay()
	neck.top_level = true
	neck.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_update_neck_transform()
	call_deferred("prewarm_shot_assets")

func _input(event):
	if dialogue_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			debug_label.visible = not debug_label.visible
			get_tree().call_group(
				&"navigation_debuggable",
				&"set_navigation_debug_visible",
				debug_label.visible
			)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F4 or event.physical_keycode == KEY_F4:
			_probe_surface_coordinate()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		rotate_player(event)
	if event.is_action_pressed("interact"):
		if current_ladder != null:
			if not ladder_mantle_active:
				release_ladder()
		else:
			_try_interact_focused()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("throw_item"):
		_throw_selected_item()
		get_viewport().set_input_as_handled()
		return
	for slot_index in INVENTORY_SIZE:
		if event.is_action_pressed("item_slot_%d" % (slot_index + 1)):
			_select_item_slot(slot_index)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_item_slot(posmod(selected_item_slot - 1, INVENTORY_SIZE))
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_item_slot((selected_item_slot + 1) % INVENTORY_SIZE)
			get_viewport().set_input_as_handled()
			return

func _process(delta):
	camera_control(delta)
	_update_neck_transform()
	_sync_interaction_outline_camera()
	hitmarker.modulate.a = clamp(hitmarker.modulate.a - delta * 3, 0, 1)
	_update_interaction_target()


func can_use_held_item() -> bool:
	return not dialogue_active and not preview_mode


func _fill_initial_inventory() -> void:
	for index in mini(initial_items.size(), INVENTORY_SIZE):
		if initial_items[index] == null:
			continue
		var item := initial_items[index].instantiate() as Item
		if item == null:
			push_warning("Initial item %d is not an Item scene" % index)
			continue
		inventory[index] = item


func add_inventory_item(item: Item) -> bool:
	for slot_index in INVENTORY_SIZE:
		if inventory[slot_index] == null:
			if item.get_parent() != null:
				item.get_parent().remove_child(item)
			inventory[slot_index] = item
			_select_item_slot(slot_index)
			return true
	hotbar.set_prompt("Inventory full")
	return false


func _throw_selected_item() -> void:
	var dropped := inventory[selected_item_slot]
	if dropped == null:
		return
	inventory[selected_item_slot] = null
	dropped.get_parent().remove_child(dropped)
	get_parent().add_child(dropped)
	dropped.release()
	var throw_direction := (-player_camera.camera.global_basis.z + Vector3.UP * 0.12).normalized()
	dropped.global_basis = player_camera.camera.global_basis * _held_item_basis(dropped.item_id)
	dropped.global_position = (
		player_camera.camera.global_position
		+ throw_direction * THROW_SPAWN_DISTANCE
	)
	dropped.linear_velocity = velocity + throw_direction * THROW_SPEED
	dropped.angular_velocity = player_camera.camera.global_basis * Vector3(5.0, 3.0, -4.0)
	hotbar.update_slots(inventory, selected_item_slot)
	_refresh_held_item()


func _update_interaction_target() -> void:
	if not hotbar.visible or not is_inside_tree() or current_ladder != null:
		# While climbing, interact only lets go, so nothing else is focused.
		_set_focused_interactable(null)
		_refresh_interaction_prompt()
		return
	var ray_start := player_camera.camera.global_position
	var ray_end := ray_start - player_camera.camera.global_basis.z * INTERACTION_DISTANCE
	var candidate := _find_visible_interactable(ray_start, ray_end)
	_set_focused_interactable(candidate)
	if not dev_probe_message.is_empty() and Time.get_ticks_msec() >= dev_probe_message_until_msec:
		dev_probe_message = ""
	# Refresh every frame so prompts pick up keybinds changed in the settings menu.
	_refresh_interaction_prompt()


func _find_visible_interactable(ray_start: Vector3, ray_end: Vector3) -> Node3D:
	# Only the first physical hit can be interacted with. Furniture, walls, doors,
	# and drawer panels therefore block loot exactly as they appear to.
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		INTERACTION_COLLISION_MASK,
		[get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result.get("collider") as Node3D
	return collider if collider != null and collider.is_in_group("interactable") else null


func _set_focused_interactable(candidate: Node3D) -> void:
	if focused_interactable == candidate:
		return
	if is_instance_valid(focused_interactable):
		focused_interactable.call("set_highlighted", false)
	focused_interactable = candidate
	if is_instance_valid(focused_interactable):
		focused_interactable.call("set_highlighted", true)
	_set_interaction_outline_enabled(is_instance_valid(focused_interactable))
	_refresh_interaction_prompt()


func _refresh_interaction_prompt() -> void:
	if Time.get_ticks_msec() < dev_probe_message_until_msec:
		hotbar.set_prompt(dev_probe_message)
	elif current_ladder != null and not ladder_mantle_active:
		hotbar.set_prompt(current_ladder.get_interaction_prompt())
	elif is_instance_valid(focused_interactable):
		hotbar.set_prompt(String(focused_interactable.call("get_interaction_prompt")))
	else:
		hotbar.set_prompt("")


func _setup_interaction_outline_overlay() -> void:
	outline_viewport = SubViewport.new()
	outline_viewport.name = "InteractionOutlineViewport"
	outline_viewport.transparent_bg = true
	outline_viewport.handle_input_locally = false
	outline_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	outline_viewport.world_3d = get_world_3d()
	add_child(outline_viewport)

	outline_camera = Camera3D.new()
	outline_camera.cull_mask = OUTLINE_VISIBILITY_MASK
	outline_camera.current = true
	var clear_environment := Environment.new()
	clear_environment.background_mode = Environment.BG_COLOR
	clear_environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	outline_camera.environment = clear_environment
	outline_viewport.add_child(outline_camera)

	outline_rect = TextureRect.new()
	outline_rect.name = "InteractionOutline"
	outline_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outline_rect.texture = outline_viewport.get_texture()
	var outline_shader_material := ShaderMaterial.new()
	outline_shader_material.shader = interaction_outline_shader
	outline_rect.material = outline_shader_material
	outline_rect.visible = false
	outline_rect.z_index = -100
	$CanvasLayer.add_child(outline_rect)
	_sync_interaction_outline_camera()


func _sync_interaction_outline_camera() -> void:
	if not is_instance_valid(outline_viewport) or not is_instance_valid(outline_camera):
		return
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	if viewport_size.x > 0 and viewport_size.y > 0 and outline_viewport.size != viewport_size:
		outline_viewport.size = viewport_size
	outline_camera.global_transform = player_camera.camera.global_transform
	outline_camera.fov = player_camera.camera.fov
	outline_camera.near = player_camera.camera.near
	outline_camera.far = player_camera.camera.far


func _set_interaction_outline_enabled(enabled: bool) -> void:
	if not is_instance_valid(outline_viewport) or not is_instance_valid(outline_rect):
		return
	outline_rect.visible = enabled
	outline_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)


func _try_interact_focused() -> void:
	if not is_instance_valid(focused_interactable):
		return
	var target := focused_interactable
	target.call("interact", self)
	if (
		not is_instance_valid(target)
		or target.is_queued_for_deletion()
		or (target is Item and (target as Item).player != null)
	):
		_set_focused_interactable(null)
	else:
		_refresh_interaction_prompt()


func _probe_surface_coordinate() -> void:
	var ray_start := player_camera.camera.global_position
	var ray_end := ray_start - player_camera.camera.global_basis.z * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	dev_probe_message_until_msec = Time.get_ticks_msec() + 4000
	if result.is_empty():
		dev_probe_message = "F4: no surface hit"
		print("[DEV_SURFACE] no surface hit")
		return
	var hit_position: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	var coordinate := "Vector3(%.3f, %.3f, %.3f)" % [
		hit_position.x, hit_position.y, hit_position.z
	]
	DisplayServer.clipboard_set(coordinate)
	dev_probe_message = "Copied %s" % coordinate
	print(
		"[DEV_SURFACE] position=%s normal=Vector3(%.3f, %.3f, %.3f) collider=%s"
		% [coordinate, hit_normal.x, hit_normal.y, hit_normal.z, result.collider]
	)


func _select_item_slot(slot_index: int) -> void:
	selected_item_slot = clampi(slot_index, 0, INVENTORY_SIZE - 1)
	hotbar.update_slots(inventory, selected_item_slot)
	_refresh_held_item()


func _refresh_held_item() -> void:
	for child in held_item_pivot.get_children():
		held_item_pivot.remove_child(child)
	var item := inventory[selected_item_slot]
	if item == null:
		return
	held_item_pivot.add_child(item)
	item.equip(self)
	if not item.fit_to_hand:
		item.transform = item.hand_transform
		return
	item.transform = Transform3D.IDENTITY
	var bounds := Item.calculate_mesh_bounds(item.model, item)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_side <= 0.0001:
		return
	var scale_factor := _held_item_display_size(item.item_id) / longest_side
	item.transform = Transform3D(
		_held_item_basis(item.item_id),
		Vector3.ZERO
	) * Transform3D(
		Basis.from_scale(Vector3.ONE * scale_factor),
		- bounds.get_center() * scale_factor
	)


func _held_item_basis(item_id: StringName) -> Basis:
	var rotation_degrees := Vector3(-12, 24, -4)
	match item_id:
		&"notebook", &"cash", &"book":
			rotation_degrees = Vector3(68, 12, -8)
		&"coins":
			rotation_degrees = Vector3(66, -10, -14)
		&"gold_bar":
			rotation_degrees = Vector3(-22, -32, 10)
		&"photo_frame", &"painting":
			rotation_degrees = Vector3(-8, 204, -4)
		&"cigarettes", &"antique_radio":
			rotation_degrees = Vector3(-12, 204, -4)
		&"flashlight":
			# The lens faces the model's +X; aim it forward, toward the crosshair.
			rotation_degrees = Vector3(0, 95, 0)
	var held_basis := Basis.from_euler(rotation_degrees * (PI / 180.0))
	if item_id == &"notebook":
		# Spin within the cover plane without flipping the front face away.
		held_basis *= Basis(Vector3.UP, PI)
	return held_basis


func _held_item_display_size(item_id: StringName) -> float:
	match item_id:
		&"coins":
			return 0.20
		&"cash", &"gold_bar":
			return 0.24
		&"pills", &"canned_food":
			return 0.25
		&"book", &"photo_frame", &"painting":
			return 0.28
		_:
			return 0.34


func _physics_process(delta):
	if current_ladder != null:
		_ladder_physics_process(delta)
		return
	if dialogue_active:
		raw_input_dir = Vector2.ZERO
		input_dir = Vector2.ZERO
	else:
		raw_input_dir = Input.get_vector("left", "right", "up", "down")
		input_dir = raw_input_dir.rotated(-rotation.y)

	vel_horizontal -= vel_horizontal.normalized() * (ACCEL_RATE / 2) * delta
	# Stand still
	if vel_horizontal.length_squared() < 1.0 and input_dir.length_squared() < 0.01:
		vel_horizontal = Vector2.ZERO

	if is_on_floor():
		state_chart.send_event("grounded")
		if vel_vertical < 0:
			if landing_sfx_armed:
				if vel_vertical < -FALL_SPEED_TO_SHAKE_CAMERA:
					player_camera.add_trauma(HEAVY_FALL_SHAKE_TRAUMA)
				play_sfx(landing_sfx)
			jumped = false
			vel_vertical = 0
		landing_sfx_armed = true
	else:
		state_chart.send_event("airborne")

	is_sprinting = not dialogue_active and Input.is_action_pressed("sprint") and not is_crouching and raw_input_dir != Vector2.ZERO
	var max_speed = WALK_SPEED * SPRINT_SPEED_MODIFIER if is_sprinting else WALK_SPEED

	var current_speed = vel_horizontal.length()
	var add_speed = clamp(max_speed - current_speed, 0.0, ACCEL_RATE * delta)

	vel_horizontal += input_dir * add_speed

	velocity = Vector3(vel_horizontal.x, vel_vertical, vel_horizontal.y)

	if is_crouching:
		velocity = velocity * CROUCH_SPEED_MODIFIER
	var movement_start := global_position
	var requested_horizontal_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	is_step_traversing = false
	var step_handled := _try_step_up(requested_horizontal_motion)
	if not step_handled:
		move_and_slide()
		_sync_vertical_state_after_move(movement_start.y)
	_recover_from_airborne_wedge(movement_start)

	if debug_label.visible:
		_log_stuck_movement(movement_start, requested_horizontal_motion)
		show_debug_label()
	_update_footsteps(movement_start)

	var held_item_sway_velocity = velocity * transform.basis
	held_item_pivot.position = lerp(held_item_pivot.position, held_item_pivot_original_pos - (held_item_sway_velocity / 500), delta * 10)


func _sync_vertical_state_after_move(start_y: float) -> void:
	# Tight imported doorways can report only their floor contact while an
	# upward jump is physically blocked. Do not keep reapplying that jump forever.
	var blocked_upward_motion := (
		is_on_floor()
		and vel_vertical > 0.0
		and global_position.y <= start_y + BLOCKED_JUMP_MOTION_EPSILON
	)
	if blocked_upward_motion:
		vel_vertical = 0.0
		velocity.y = 0.0
		jumped = false
		step_debug_reason = "blocked jump recovered"
	elif is_on_ceiling():
		vel_vertical = minf(vel_vertical, 0.0)
	elif not is_on_floor():
		vel_vertical = velocity.y


func _try_step_up(horizontal_motion: Vector3) -> bool:
	if jumped:
		step_debug_reason = "not grounded"
		return false
	var result := CharacterStepSolver.try_step_up(
		self,
		horizontal_motion,
		max_step_height
	)
	step_debug_reason = result.reason
	if not result.handled:
		return false
	vel_vertical = 0.0
	is_step_traversing = true
	# Keep the view at its pre-step height while the body is already supported.
	if result.step_height >= CharacterStepSolver.MIN_STEP_HEIGHT:
		neck_offset_y -= result.step_height
	return true


func _log_stuck_movement(movement_start: Vector3, requested_motion: Vector3) -> void:
	if raw_input_dir.length_squared() < 0.01:
		return
	var requested_distance := requested_motion.length()
	if requested_distance < STUCK_MIN_REQUEST_DISTANCE:
		return
	var actual_motion := global_position - movement_start
	actual_motion.y = 0.0
	if actual_motion.length() >= requested_distance * STUCK_PROGRESS_RATIO:
		return
	var now := Time.get_ticks_msec()
	if now - last_stuck_log_msec < STUCK_LOG_INTERVAL_MSEC:
		return
	last_stuck_log_msec = now

	var blocker := "none"
	var contact := Vector3.ZERO
	var normal := Vector3.ZERO
	var collision := KinematicCollision3D.new()
	var probe_motion := requested_motion.normalized() * maxf(requested_distance, 0.08)
	if test_move(global_transform, probe_motion, collision) and collision.get_collision_count() > 0:
		var collider := collision.get_collider(0)
		if collider is Node:
			blocker = str((collider as Node).get_path())
		elif collider != null:
			blocker = collider.get_class()
		contact = collision.get_position(0)
		normal = collision.get_normal(0)

	var log_line := (
		"PLAYER_STUCK xyz=(%.3f, %.3f, %.3f) input=(%.2f, %.2f) "
		+"requested=(%.3f, %.3f) actual=%.4f on_floor=%s step=%s "
		+"step_result=\"%s\" pitch_deg=%.1f yaw_deg=%.1f blocker=%s "
		+"contact=(%.3f, %.3f, %.3f) normal=(%.3f, %.3f, %.3f)"
	) % [
			global_position.x, global_position.y, global_position.z,
			raw_input_dir.x, raw_input_dir.y,
			requested_motion.x, requested_motion.z, actual_motion.length(),
			str(is_on_floor()), str(is_step_traversing), step_debug_reason,
			player_camera.rotation_degrees.x, rotation_degrees.y, blocker,
			contact.x, contact.y, contact.z,
			normal.x, normal.y, normal.z,
		]
	print(log_line)


func _recover_from_airborne_wedge(movement_start: Vector3) -> void:
	if is_on_floor():
		airborne_wedge_frames = 0
		jump_recovery_valid = false
		return
	if (
		not jump_recovery_valid
		or vel_vertical > 0.0
		or global_position.y <= jump_recovery_position.y + AIRBORNE_WEDGE_MIN_HEIGHT
	):
		airborne_wedge_frames = 0
		return
	if global_position.distance_to(movement_start) > AIRBORNE_WEDGE_MOTION_EPSILON:
		airborne_wedge_frames = 0
		return

	airborne_wedge_frames += 1
	if airborne_wedge_frames < AIRBORNE_WEDGE_RECOVERY_FRAMES:
		return

	global_position = jump_recovery_position
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	vel_horizontal = Vector2.ZERO
	vel_vertical = 0.0
	jumped = false
	jump_recovery_valid = false
	airborne_wedge_frames = 0
	step_debug_reason = "recovered from airborne wedge"
	apply_floor_snap()

func play_sfx(sfx: AudioStream):
	audio_player.play(sfx, "SFX", true)

func _update_footsteps(movement_start: Vector3) -> void:
	var horizontal_distance := Vector2(
		global_position.x - movement_start.x,
		global_position.z - movement_start.z
	).length()
	if not is_on_floor() or raw_input_dir == Vector2.ZERO or horizontal_distance < 0.0005:
		footstep_distance_traveled = next_footstep_distance * 0.5
		return

	footstep_distance_traveled += horizontal_distance
	if footstep_distance_traveled < next_footstep_distance:
		return
	footstep_distance_traveled = fmod(footstep_distance_traveled, next_footstep_distance)
	next_footstep_distance = randf_range(FOOTSTEP_MIN_DISTANCE, FOOTSTEP_MAX_DISTANCE)
	var profile := _footstep_profile(_current_footstep_surface())
	var footstep_player := audio_player.prepare(landing_sfx, "SFX")
	footstep_player.volume_db = randf_range(profile.z, profile.w)
	footstep_player.pitch_scale = randf_range(profile.x, profile.y)
	footstep_player.call_deferred("play")


func _current_footstep_surface() -> StringName:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.25,
		global_position + Vector3.DOWN * 1.0,
		FOOTSTEP_SURFACE_MASK,
		[get_rid()]
	)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return &"concrete"
	var collider := hit.get("collider") as CollisionObject3D
	if collider == null:
		return &"concrete"
	if collider.has_meta(&"footstep_surface"):
		return StringName(collider.get_meta(&"footstep_surface"))
	var surface_hint := String(collider.name).to_lower()
	for surface in [&"wood", &"carpet", &"metal", &"tile", &"grass"]:
		if String(surface) in surface_hint:
			return surface
	return &"concrete"


func _footstep_profile(surface: StringName) -> Vector4:
	# x/y are pitch range; z/w are volume range in decibels.
	match surface:
		&"wood":
			return Vector4(0.62, 0.82, -38.0, -33.0)
		&"carpet":
			return Vector4(0.44, 0.58, -43.0, -38.0)
		&"metal":
			return Vector4(1.02, 1.28, -40.0, -34.0)
		&"tile":
			return Vector4(0.82, 1.02, -40.0, -34.0)
		&"grass":
			return Vector4(0.48, 0.68, -43.0, -37.0)
		_:
			return Vector4(0.54, 0.72, -39.0, -33.0)

func show_debug_label():
	var h_speed = snapped(Vector3(velocity.x, 0, velocity.z).length(), 0.1)
	var v_speed = snapped(vel_vertical, 0.1)
	var position := global_position
	Engine.get_frames_per_second()
	debug_label.text = "F3: hide debug"
	debug_label.text += "\nXYZ: %.3f, %.3f, %.3f" % [position.x, position.y, position.z]
	debug_label.text += "\nYaw: %.1f | Pitch: %.1f" % [rotation_degrees.y, player_camera.rotation_degrees.x]
	debug_label.text += "\nFPS: {0}".format([Engine.get_frames_per_second()])
	debug_label.text += "\nHSpeed: {0} u/s\nVSpeed: {1} u/s".format([h_speed, v_speed])
	debug_label.text += "\nOn ground: {0}".format([is_on_floor()])
	debug_label.text += "\nStep traversal: {0}".format([is_step_traversing])
	debug_label.text += "\nStep result: {0}".format([step_debug_reason])
	debug_label.text += "\nIs crouching: {0} | Is sprinting: {1}".format([is_crouching, is_sprinting])
	debug_label.text += "\nCoyote jump: {0}".format([can_coyote_jump])
	var selected_item := inventory[selected_item_slot]
	var selected_name := selected_item.display_name if selected_item != null else "Empty"
	debug_label.text += "\nSelected item: {0}".format([selected_name])

func jump(multiplier = 1.0):
	jump_recovery_position = global_position
	jump_recovery_valid = true
	airborne_wedge_frames = 0
	vel_vertical = JUMP_FORCE * multiplier
	jumped = true
	state_chart.send_event("jump")
	if _can_stand():
		is_crouching = false

# Screenshake and recoil from a fired shot.
func apply_shot_kick(screenshake_amount: float) -> void:
	player_camera.add_trauma(screenshake_amount)
	player_camera.rotate_x(screenshake_amount / RECOIL_COEFFICIENT)
	player_camera.rotate_y(randf_range(-screenshake_amount / RECOIL_COEFFICIENT, screenshake_amount / RECOIL_COEFFICIENT))

func rotate_player(event):
	rotate(Vector3(0, -1, 0), event.relative.x * (GameManager.mouse_sensitivity / 10000))
	player_camera.rotate_x(-event.relative.y * (GameManager.mouse_sensitivity / 10000))
	player_camera.rotation.y = 0
	player_camera.rotation.z = 0
	player_camera.rotation.x = clamp(player_camera.global_rotation.x, deg_to_rad(-89), deg_to_rad(89))

func camera_control(delta):
	# Tilt camera
	if GameManager.camera_tilt:
		if raw_input_dir.x < 0:
			neck_tilt = lerp(neck_tilt, deg_to_rad(3.0), delta * 5)
		elif raw_input_dir.x > 0:
			neck_tilt = lerp(neck_tilt, deg_to_rad(-3.0), delta * 5)
		else:
			neck_tilt = lerp(neck_tilt, deg_to_rad(0), delta * 5)

	# Lower camera
	if is_crouching:
		neck_offset_y = lerp(neck_offset_y, -1.0, delta * 5)
	else:
		neck_offset_y = lerp(neck_offset_y, 0.0, delta * 5)

func _on_grounded_state_input(event: InputEvent):
	if dialogue_active:
		return
	if current_ladder != null:
		_ladder_state_input(event)
		return
	if event.is_action_pressed("jump"):
		jump()

func _on_grounded_state_physics_processing(_delta: float):
	if current_ladder != null:
		return
	if dialogue_active:
		if _can_stand():
			is_crouching = false
		return
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

func _apply_crouch_collision() -> void:
	standing_collision.disabled = is_crouching
	crouching_collision.disabled = not is_crouching

# True when the standing capsule fits at the current position (no low ceiling overhead).
func _can_stand() -> bool:
	return _standing_capsule_fits(global_position)


# True when the standing capsule fits with the body origin at body_position.
func _standing_capsule_fits(body_position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_collision.shape
	query.transform = Transform3D(
		standing_collision.global_basis,
		body_position + (standing_collision.global_position - global_position)
	)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _on_airborne_state_input(event: InputEvent):
	if dialogue_active:
		return
	if current_ladder != null:
		_ladder_state_input(event)
		return
	if event.is_action_pressed("jump") and can_coyote_jump and not jumped:
		jump()

func _on_airborne_state_entered() -> void:
	if not jumped:
		coyote_timer.start()
		can_coyote_jump = true

func _on_airborne_state_physics_processing(delta: float) -> void:
	if current_ladder != null:
		return
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)

func grab_ladder(ladder: Ladder) -> void:
	current_ladder = ladder
	ladder_normal = ladder.get_climb_normal(global_position)
	ladder_mantle_active = false
	ladder_rung_distance = 0.0
	is_sprinting = false
	if _can_stand():
		is_crouching = false
	vel_horizontal = Vector2.ZERO
	vel_vertical = 0.0
	velocity = Vector3.ZERO
	jumped = false
	can_coyote_jump = false
	jump_recovery_valid = false
	var feet_y := global_position.y - _standing_half_height()
	if is_on_floor() and feet_y >= ladder.get_top_y() - LADDER_TOP_ENTRY_MARGIN:
		_try_start_ladder_mantle(false)
	_refresh_interaction_prompt()


func release_ladder() -> void:
	current_ladder = null
	ladder_mantle_active = false
	vel_horizontal = Vector2.ZERO
	vel_vertical = 0.0
	velocity = Vector3.ZERO
	# Falling straight off a ladder is not a ledge walk-off; no coyote jump.
	jumped = not is_on_floor()
	_refresh_interaction_prompt()


func _ladder_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not ladder_mantle_active:
		var push := ladder_normal * LADDER_JUMP_OFF_SPEED
		release_ladder()
		jump(LADDER_JUMP_OFF_MULTIPLIER)
		vel_horizontal = Vector2(push.x, push.z)


func _ladder_physics_process(delta: float) -> void:
	raw_input_dir = Vector2.ZERO
	input_dir = Vector2.ZERO
	if not is_instance_valid(current_ladder) or not current_ladder.is_inside_tree():
		release_ladder()
		return
	if ladder_mantle_active:
		_process_ladder_mantle(delta)
		return

	var climb_input := 0.0 if dialogue_active else Input.get_axis("down", "up")
	var feet_y := global_position.y - _standing_half_height()
	if climb_input > 0.0 and feet_y >= current_ladder.get_top_y():
		climb_input = 0.0
		if _try_start_ladder_mantle(true):
			return

	var anchor := current_ladder.get_climb_point(ladder_normal)
	var snap := Vector3(anchor.x - global_position.x, 0.0, anchor.z - global_position.z)
	var start_y := global_position.y
	velocity = snap * LADDER_SNAP_RATE + Vector3.UP * climb_input * current_ladder.climb_speed
	move_and_slide()
	_update_ladder_rung_sound(absf(global_position.y - start_y))
	if climb_input < 0.0 and is_on_floor():
		# Stepped off the bottom rung.
		release_ladder()


# Climbs over the top of the ladder to its other side when there is room to
# stand there: off the ladder onto the floor, or from the floor onto the ladder.
func _try_start_ladder_mantle(leave_ladder: bool) -> bool:
	var exit_point := current_ladder.get_climb_point(-ladder_normal)
	var target := Vector3(
		exit_point.x,
		current_ladder.get_top_y() + _standing_half_height() + LADDER_MANTLE_CLEARANCE,
		exit_point.z
	)
	if not _standing_capsule_fits(target):
		return false
	if _can_stand():
		is_crouching = false
	ladder_mantle_target = target
	ladder_mantle_active = true
	ladder_mantle_leaves = leave_ladder
	ladder_normal = - ladder_normal
	_refresh_interaction_prompt()
	return true


func _process_ladder_mantle(delta: float) -> void:
	var step := LADDER_MANTLE_SPEED * delta
	if global_position.y < ladder_mantle_target.y:
		global_position.y = move_toward(global_position.y, ladder_mantle_target.y, step)
		return
	var flat_target := Vector3(ladder_mantle_target.x, global_position.y, ladder_mantle_target.z)
	global_position = global_position.move_toward(flat_target, step)
	if not global_position.is_equal_approx(flat_target):
		return
	ladder_mantle_active = false
	if ladder_mantle_leaves:
		release_ladder()
		jumped = false
		apply_floor_snap()
	else:
		_refresh_interaction_prompt()


func _update_ladder_rung_sound(climbed: float) -> void:
	ladder_rung_distance += climbed
	if ladder_rung_distance < LADDER_RUNG_SOUND_DISTANCE:
		return
	ladder_rung_distance = 0.0
	var profile := _footstep_profile(&"metal")
	var rung_player := audio_player.prepare(landing_sfx, "SFX")
	rung_player.volume_db = randf_range(profile.z, profile.w)
	rung_player.pitch_scale = randf_range(profile.x, profile.y)
	rung_player.call_deferred("play")


func _standing_half_height() -> float:
	var capsule := standing_collision.shape as CapsuleShape3D
	return capsule.height * 0.5 if capsule != null else 1.0


func flash_hitmarker(color: Color = Color.YELLOW):
	hitmarker.modulate = color
	hitmarker.modulate.a = 1

func create_hitscan_attack(start_pos: Vector3, direction: Vector3, bounce_left: int, gun_projectile: PackedScene, damage: int, is_pierce: bool = false, excluded_rids: Array[RID] = []):
	if direction.is_zero_approx():
		return

	var query := PhysicsRayQueryParameters3D.create(start_pos, start_pos + direction, HITSCAN_COLLISION_MASK)
	query.exclude = excluded_rids
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		spawn_hitscan(gun_projectile, start_pos, start_pos + direction)
		return

	var hit_position: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	var collider: Object = result.collider
	var bullet_inst := spawn_hitscan(gun_projectile, start_pos, hit_position)

	if collider is Enemy:
		var enemy := collider as Enemy
		var killed := enemy.damaged(damage)
		flash_hitmarker(Color.RED if killed else Color.YELLOW)
		spawn_particle_effect(enemy.bloodsplatter, hit_position, hit_normal)

		if is_pierce:
			var travel_direction := direction.normalized()
			var remaining_distance := direction.length() - start_pos.distance_to(hit_position)
			if remaining_distance > HITSCAN_SURFACE_OFFSET:
				var next_excluded_rids := excluded_rids.duplicate()
				next_excluded_rids.append(result.rid)
				create_hitscan_attack(
					hit_position + travel_direction * HITSCAN_SURFACE_OFFSET,
					travel_direction * remaining_distance,
					bounce_left,
					gun_projectile,
					damage,
					true,
					next_excluded_rids
				)
			return
	else:
		spawn_particle_effect(bullet_inst.spark_effect, hit_position, hit_normal)

	if bounce_left > 0:
		var bounced_direction := direction.bounce(hit_normal)
		var bounced_origin := hit_position + bounced_direction.normalized() * HITSCAN_SURFACE_OFFSET
		create_hitscan_attack(bounced_origin, bounced_direction, bounce_left - 1, gun_projectile, damage, is_pierce)

func spawn_hitscan(scene: PackedScene, start_pos: Vector3, end_pos: Vector3) -> GunHitscan:
	var key := scene.resource_path
	var pool: Array = hitscan_pools.get(key, [])
	var projectile: GunHitscan
	if pool.is_empty():
		projectile = scene.instantiate() as GunHitscan
		projectile.expired.connect(_on_hitscan_expired.bind(key))
		get_parent().add_child(projectile)
	else:
		projectile = pool.pop_back() as GunHitscan
	hitscan_pools[key] = pool
	projectile.activate(start_pos, end_pos)
	return projectile

func spawn_particle_effect(scene: PackedScene, position: Vector3, normal: Vector3) -> void:
	if scene == null:
		return
	var key := scene.resource_path
	var pool: Array = particle_pools.get(key, [])
	var effect: SelfDestruct3DParticle
	if pool.is_empty():
		effect = scene.instantiate() as SelfDestruct3DParticle
		effect.pool_managed = true
		effect.released.connect(_on_particle_released.bind(key))
		get_parent().add_child(effect)
	else:
		effect = pool.pop_back() as SelfDestruct3DParticle
	particle_pools[key] = pool
	effect.global_position = position
	effect.global_rotation = Vector3.ZERO
	if normal.is_equal_approx(Vector3.DOWN):
		effect.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		effect.rotation_degrees.x = 90
	else:
		effect.look_at(position + normal, Vector3.UP)
	effect.activate()

func _on_hitscan_expired(projectile: GunHitscan, key: String) -> void:
	var pool: Array = hitscan_pools.get(key, [])
	pool.append(projectile)
	hitscan_pools[key] = pool

func _on_particle_released(effect: SelfDestruct3DParticle, key: String) -> void:
	var pool: Array = particle_pools.get(key, [])
	pool.append(effect)
	particle_pools[key] = pool

func prewarm_shot_assets() -> void:
	for gun_scene in prewarmed_gun_scenes:
		var gun := gun_scene.instantiate() as Gun
		prewarm_hitscan(gun.primary_projectile)
		gun.free()
	prewarm_enemy_effects(get_parent())
	shot_assets_ready = true

func set_preview_mode(enabled: bool) -> void:
	preview_mode = enabled
	held_item_pivot.visible = not enabled
	aim_reticle.visible = not enabled
	hitmarker.visible = not enabled
	hotbar.visible = not enabled and not dialogue_active
	debug_label.visible = false
	get_tree().call_group(
		&"navigation_debuggable",
		&"set_navigation_debug_visible",
		false
	)
	pause_ui.visible = false
	pause_ui.is_paused = false
	pause_ui.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_ALWAYS
	if not enabled:
		_refresh_held_item()


func _on_dialogue_started(_resource: DialogueResource) -> void:
	dialogue_active = true
	if _can_stand():
		is_crouching = false
	hotbar.hide()
	_set_focused_interactable(null)


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	dialogue_active = false
	hotbar.visible = not preview_mode

func snap_to_floor(max_distance: float = 100.0) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP,
		global_position + Vector3.DOWN * max_distance,
		1,
		[get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var capsule := standing_collision.shape as CapsuleShape3D
	var half_height := capsule.height * 0.5 if capsule != null else 1.0
	global_position.y = result.position.y + half_height + 0.01
	reset_physics_interpolation()
	_update_neck_transform()


func _update_neck_transform() -> void:
	var origin := get_global_transform_interpolated().origin if is_inside_tree() else global_position
	neck.global_transform = Transform3D(
		global_basis * Basis.from_euler(Vector3(0.0, 0.0, neck_tilt)),
		origin + global_basis * Vector3(0.0, neck_offset_y, 0.0)
	)

func render_prewarmed_shot_assets() -> void:
	var warmup_start := player_camera.global_position
	var warmup_end := warmup_start - player_camera.global_basis.z * 2.0
	for pool in hitscan_pools.values():
		for projectile: GunHitscan in pool:
			projectile.activate(warmup_start, warmup_end)
	for pool in particle_pools.values():
		for effect: SelfDestruct3DParticle in pool:
			effect.global_position = warmup_end
			effect.activate()

	await get_tree().process_frame
	for pool in hitscan_pools.values():
		for projectile: GunHitscan in pool:
			projectile.prepare_for_pool()
	for pool in particle_pools.values():
		for effect: SelfDestruct3DParticle in pool:
			effect.prepare_for_pool()

func prewarm_hitscan(scene: PackedScene) -> void:
	if scene == null:
		return
	var key := scene.resource_path
	var pool: Array = hitscan_pools.get(key, [])
	if not pool.is_empty():
		return
	var projectile := scene.instantiate() as GunHitscan
	projectile.expired.connect(_on_hitscan_expired.bind(key))
	get_parent().add_child(projectile)
	projectile.prepare_for_pool()
	pool.append(projectile)
	hitscan_pools[key] = pool
	prewarm_particle(projectile.spark_effect)

func prewarm_particle(scene: PackedScene) -> void:
	if scene == null:
		return
	var key := scene.resource_path
	var pool: Array = particle_pools.get(key, [])
	if not pool.is_empty():
		return
	var effect := scene.instantiate() as SelfDestruct3DParticle
	effect.pool_managed = true
	effect.released.connect(_on_particle_released.bind(key))
	get_parent().add_child(effect)
	effect.prepare_for_pool()
	pool.append(effect)
	particle_pools[key] = pool

func prewarm_enemy_effects(node: Node) -> void:
	if node is Enemy:
		prewarm_particle((node as Enemy).bloodsplatter)
	for child in node.get_children():
		prewarm_enemy_effects(child)

func _on_coyote_timer_timeout():
	can_coyote_jump = false
