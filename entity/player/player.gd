extends CharacterBody3D
class_name Player

@export var max_air_jump = 2
@export var dash_cd: float = 0.5
@export var aim_ray_prefab: PackedScene
@export_range(0.0, 0.6, 0.05) var max_step_height := 0.35
@export_range(-89.0, 89.0, 0.1) var initial_camera_pitch_degrees := 0.0

@onready var player_camera: ShakeableCamera = $Neck/ShakeableCamera
@onready var debug_label: Label = $Neck/ShakeableCamera/DebugLabel
@onready var dash_duration_timer: Timer = $DashDuration
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var neck: Node3D = $Neck
@onready var state_chart: StateChart = $StateChart
@onready var wall_raycast: RayCast3D = $WallRaycast
@onready var audio_player: CharacterAudioPlayer3D = $CharacterAudioPlayer3D

@onready var gun_container = $Neck/ShakeableCamera/GunContainer
@onready var held_item_pivot: Node3D = $Neck/ShakeableCamera/HeldItemPivot
@onready var aim_ray: AimRay = $Neck/ShakeableCamera/AimRay
@onready var aim_reticle: TextureRect = $Neck/ShakeableCamera/AimRecticle
@onready var hitmarker: TextureRect = $Neck/ShakeableCamera/HitMarker
@onready var pause_ui: PauseUI = $CanvasLayer/PauseUI
@onready var hotbar: HotbarUI = $CanvasLayer/Hotbar

var landing_sfx = preload("res://asset/sfx/player/jump_landing.wav")
var starter_pistol_icon = preload("res://asset/ui/starter_pistol_icon.png")
var starter_pistol_scene = preload("res://entity/weapon/gun/StarterPistol.tscn")
var pickup_item_scene = preload("res://entity/item/PickupItem.tscn")
var interaction_outline_shader = preload("res://material/interaction_outline.gdshader")

const MAX_SPEED = 4.0
const JUMP_FORCE = 5.0

const MAX_FALL_SPEED = 50.0
const ACCEL_RATE = 40.0
const GRAVITY = 14
const FALL_SPEED_TO_SHAKE_CAMERA = 15
const HEAVY_FALL_SHAKE_TRAUMA = 0.8
const SLIDE_SHAKE_TRAUMA = 0.1
const MIN_HEIGHT_TO_SLAM = 1.5
const SWAP_GUN_TIME = 0.3
const RECOIL_COEFFICIENT = 10
const BULLET_SPAWN_POS_VARIATION = 10
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

const DASH_SPEED_MODIFIER = 2
const CROUCH_SPEED_MODIFIER = 0.5
const SPRINT_SPEED_MODIFIER = 1.6

var floor_col_pos = Vector3.ZERO
var jumped = false
var can_coyote_jump = false
var vel_horizontal = Vector2(0, 0)
var vel_vertical = 0
var is_dashing = false
var is_sprinting = false
var is_crouching:
	set(value):
		is_crouching = value
var raw_input_dir = Vector2(0, 0)
var input_dir = Vector2(0, 0)
var bonus_speed = 0
var gun_container_original_pos: Vector3
var last_dashed_timestamp
var current_air_jump_count = 0
var slide_dir = Vector2(0, 0)
var current_gun_slot = 0
var is_swapping_gun = false
var hitscan_pools: Dictionary = {}
var particle_pools: Dictionary = {}
var shot_assets_ready := false
var attack_input_armed := false
var landing_sfx_armed := false
var is_step_traversing := false
var step_debug_reason := "idle"
var last_stuck_log_msec := 0
var inventory: Array[Dictionary] = []
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

func _ready():
	GameManager.player = self
	player_camera.set_fov(GameManager.camera_fov)
	player_camera.rotation_degrees.x = initial_camera_pitch_degrees
	if not GameManager.is_preparing_first_level:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	gun_container_original_pos = gun_container.position
	last_dashed_timestamp = 0
	current_gun_slot = 0
	gun_container.visible = true
	for child in gun_container.get_children():
		child.visible = false
	gun_container.get_child(current_gun_slot).visible = true
	for index in INVENTORY_SIZE:
		inventory.append({})
	inventory[0] = {
		"id": &"starter_pistol",
		"name": "Pistol",
		"kind": "gun",
		"gun_slot": 0,
		"icon": starter_pistol_icon,
		"scene": starter_pistol_scene,
		"display_size": 0.55,
		"mass": 1.0,
	}
	hotbar.update_slots(inventory, selected_item_slot)
	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	dialogue_manager.dialogue_started.connect(_on_dialogue_started)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	_refresh_held_item()
	_setup_interaction_outline_overlay()
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
	if event.is_action_pressed("dash"):
		if last_dashed_timestamp + dash_cd * 1000 <= Time.get_ticks_msec():
			last_dashed_timestamp = Time.get_ticks_msec()
			is_dashing = true
			vel_vertical = 0
			dash_duration_timer.start()

func _process(delta):
	_sync_interaction_outline_camera()
	hitmarker.modulate.a = clamp(hitmarker.modulate.a - delta * 3, 0, 1)
	_update_interaction_target()
	# Disarming also stops the click that closes the last dialogue line from firing.
	if dialogue_active:
		attack_input_armed = false
		return
	if not _selected_item_is_gun():
		attack_input_armed = false
		return
	if not attack_input_armed:
		attack_input_armed = (
			not Input.is_action_pressed("primary_attack")
			and not Input.is_action_pressed("secondary_attack")
		)
		return
	if not is_swapping_gun:
		check_primary_attack()
		check_secondary_attack()


func add_inventory_item(
	item_id: StringName,
	display_name: String,
	model_scene: PackedScene,
	icon: Texture2D,
	display_size := 0.55,
	item_mass := 0.5,
	item_kind: StringName = &"item",
	gun_slot := -1
) -> bool:
	for slot_index in INVENTORY_SIZE:
		if inventory[slot_index].is_empty():
			inventory[slot_index] = {
				"id": item_id,
				"name": display_name,
				"scene": model_scene,
				"icon": icon,
				"display_size": display_size,
				"mass": item_mass,
				"kind": item_kind,
				"gun_slot": gun_slot,
			}
			_select_item_slot(slot_index)
			return true
	hotbar.set_prompt("Inventory full")
	return false


func _throw_selected_item() -> void:
	var item := inventory[selected_item_slot]
	if item.is_empty():
		return
	var dropped := pickup_item_scene.instantiate() as PickupItem
	dropped.item_id = StringName(item.get("id", &""))
	dropped.display_name = String(item.get("name", "Item"))
	dropped.item_kind = StringName(item.get("kind", &"item"))
	dropped.gun_slot = int(item.get("gun_slot", -1))
	dropped.model_scene = item.get("scene") as PackedScene
	dropped.icon = item.get("icon") as Texture2D
	dropped.display_size = float(item.get("display_size", 0.55))
	dropped.item_mass = float(item.get("mass", 0.5))
	get_parent().add_child(dropped)
	var throw_direction := (-player_camera.camera.global_basis.z + Vector3.UP * 0.12).normalized()
	dropped.global_basis = player_camera.camera.global_basis * _held_item_basis(item)
	dropped.global_position = (
		player_camera.camera.global_position
		+ throw_direction * THROW_SPAWN_DISTANCE
	)
	dropped.linear_velocity = velocity + throw_direction * THROW_SPEED
	dropped.angular_velocity = player_camera.camera.global_basis * Vector3(5.0, 3.0, -4.0)
	inventory[selected_item_slot] = {}
	hotbar.update_slots(inventory, selected_item_slot)
	_refresh_held_item()


func _update_interaction_target() -> void:
	if not hotbar.visible or not is_inside_tree():
		_set_focused_interactable(null)
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
	# The first physics hit is the visibility test. A wall, vehicle body, or any
	# other collider in front of an interactable blocks it for every item type.
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		INTERACTION_COLLISION_MASK,
		[get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result.collider as Node3D
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
	if not is_instance_valid(target) or target.is_queued_for_deletion():
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
	attack_input_armed = false
	hotbar.update_slots(inventory, selected_item_slot)
	_refresh_held_item()


func _refresh_held_item() -> void:
	for child in held_item_pivot.get_children():
		child.free()
	gun_container.visible = false
	for child in gun_container.get_children():
		child.visible = false
	var item := inventory[selected_item_slot]
	if item.is_empty():
		return
	if item.get("kind", "") == "gun":
		current_gun_slot = int(item.get("gun_slot", 0))
		gun_container.visible = true
		var gun := gun_container.get_child(current_gun_slot) as Gun
		gun.visible = true
		gun.reset_for_gameplay()
		return
	var model_scene := item.get("scene") as PackedScene
	if model_scene == null:
		return
	var holder := Node3D.new()
	holder.basis = _held_item_basis(item)
	held_item_pivot.add_child(holder)
	var model := model_scene.instantiate() as Node3D
	holder.add_child(model)
	var bounds := _calculate_model_bounds(model)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_side <= 0.0001:
		return
	var scale_factor := 0.34 / longest_side
	model.scale = Vector3.ONE * scale_factor
	model.position = - bounds.get_center() * scale_factor


func _selected_item_is_gun() -> bool:
	if inventory.is_empty():
		return false
	return inventory[selected_item_slot].get("kind", "") == "gun"


func _held_item_basis(item: Dictionary) -> Basis:
	var item_id := StringName(item.get("id", &""))
	var rotation_degrees := Vector3(-12, 24, -4)
	if item_id == &"notebook":
		rotation_degrees = Vector3(78, 12, -4)
	elif item_id == &"cigarettes" or item_id == &"antique_radio":
		rotation_degrees = Vector3(-12, 204, -4)
	var held_basis := Basis.from_euler(rotation_degrees * (PI / 180.0))
	if item_id == &"notebook":
		# Spin within the cover plane without flipping the front face away.
		held_basis *= Basis(Vector3.UP, PI)
	return held_basis


func _calculate_model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var has_point := false
	var mesh_instances: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		mesh_instances.append(root as MeshInstance3D)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(child as MeshInstance3D)
	var inverse_root := root.global_transform.affine_inverse()
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh == null:
			continue
		var local_transform := inverse_root * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.mesh.get_aabb()
		var bounds_end := mesh_bounds.position + mesh_bounds.size
		for x in [mesh_bounds.position.x, bounds_end.x]:
			for y in [mesh_bounds.position.y, bounds_end.y]:
				for z in [mesh_bounds.position.z, bounds_end.z]:
					var point := local_transform * Vector3(x, y, z)
					if not has_point:
						result = AABB(point, Vector3.ZERO)
						has_point = true
					else:
						result = result.expand(point)
	return result

func _physics_process(delta):
	if dialogue_active:
		raw_input_dir = Vector2.ZERO
		input_dir = Vector2.ZERO
		is_dashing = false
	elif is_dashing:
		if raw_input_dir == Vector2.ZERO:
			raw_input_dir = Vector2(0, -1)
			input_dir = raw_input_dir.rotated(-rotation.y)
	else:
		raw_input_dir = Input.get_vector("left", "right", "up", "down")
		input_dir = raw_input_dir.rotated(-rotation.y)

	vel_horizontal -= vel_horizontal.normalized() * (ACCEL_RATE / 2) * delta
	# Stand still
	if vel_horizontal.length_squared() < 1.0 and input_dir.length_squared() < 0.01:
		vel_horizontal = Vector2.ZERO

	if is_on_floor():
		state_chart.send_event("grounded")
		current_air_jump_count = 0
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
	var max_speed = MAX_SPEED * SPRINT_SPEED_MODIFIER if is_sprinting else MAX_SPEED

	var current_speed = vel_horizontal.length()
	var add_speed = clamp(max_speed - current_speed, 0.0, ACCEL_RATE * delta)

	if is_dashing:
		vel_horizontal = input_dir * MAX_SPEED
	else:
		vel_horizontal += input_dir * add_speed

	velocity = Vector3(vel_horizontal.x, vel_vertical, vel_horizontal.y)

	# Bonus speed
	if is_dashing:
		bonus_speed = MAX_SPEED * (DASH_SPEED_MODIFIER - 1)
	else:
		bonus_speed = lerpf(bonus_speed, 0, delta * 9)

	var velocity_dir = velocity.normalized()

	if is_crouching:
		velocity = velocity * CROUCH_SPEED_MODIFIER
	velocity += Vector3(velocity_dir.x, 0, velocity_dir.z) * bonus_speed
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

	var gun_sway_velocity = velocity * transform.basis
	if not is_swapping_gun:
		gun_container.position = lerp(gun_container.position, gun_container_original_pos - (gun_sway_velocity / 500), delta * 10)
	camera_control(delta)


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
		current_air_jump_count = 0
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
		neck.position.y -= result.step_height
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
	debug_label.text += "\nOn ground: {0} | wall-cling: {1}".format([is_on_floor(), moving_toward_wall()])
	debug_label.text += "\nStep traversal: {0}".format([is_step_traversing])
	debug_label.text += "\nStep result: {0}".format([step_debug_reason])
	debug_label.text += "\nIs dashing: {0} | Is crouching: {1} | Is sprinting: {2}".format([is_dashing, is_crouching, is_sprinting])
	debug_label.text += "\nAir jumps left: {0}".format([max_air_jump - current_air_jump_count])
	debug_label.text += "\nCoyote jump: {0}".format([can_coyote_jump])
	var selected_name := String(inventory[selected_item_slot].get("name", "Empty"))
	debug_label.text += "\nSelected item: {0}".format([selected_name])

func jump(multiplier = 1.0):
	jump_recovery_position = global_position
	jump_recovery_valid = true
	airborne_wedge_frames = 0
	vel_vertical = JUMP_FORCE * multiplier
	jumped = true
	state_chart.send_event("jump")
	is_dashing = false
	is_crouching = false

func check_primary_attack():
	if Input.is_action_pressed("primary_attack"):
		var gun: Gun = gun_container.get_child(current_gun_slot)
		if not gun.try_primary_attack():
			return
		gun.play_primary_attack_anim()
		perform_attack(gun)

func check_secondary_attack():
	var gun: Gun = gun_container.get_child(current_gun_slot)
	match gun.data.secondary_type:
		EnumAutoload.GunSecondaryAttackType.CLICK_ATTACK:
			if Input.is_action_just_pressed("secondary_attack") and gun.try_secondary_attack():
				gun.play_secondary_attack_anim()
				perform_attack(gun, true)
		EnumAutoload.GunSecondaryAttackType.CLICK_NONATTACK:
			if Input.is_action_just_pressed("secondary_attack") and gun.try_secondary_attack():
				gun.play_secondary_attack_anim()
				# TODO: gun secondary nonattack implementation
		EnumAutoload.GunSecondaryAttackType.HOLD:
			if Input.is_action_pressed("secondary_attack") and gun.try_secondary_attack():
				if not gun.check_if_animation_playing("secondary_attack_hold"):
					gun.play_secondary_attack_anim()
					# TODO: gun secondary hold implementation
		EnumAutoload.GunSecondaryAttackType.HOLD_AND_RELEASE:
			if Input.is_action_pressed("secondary_attack") and gun.try_secondary_attack(true):
				# Make sure only played once
				if not gun.check_if_animation_playing("secondary_attack_hold"):
					gun.start_charge()
					gun.play_secondary_attack_hold_anim()
			elif Input.is_action_just_released("secondary_attack"):
				if gun.release_charge():
					if gun.try_secondary_attack():
						gun.play_secondary_attack_release_anim()
						perform_attack(gun, true, gun.data.secondary_bounce_time, gun.data.secondary_pierce)
						# TODO: gun secondary hold implementation
					else:
						gun.play_idle_anim()
				else:
					gun.play_idle_anim()

func perform_attack(gun: Gun, is_secondary: bool = false, bounce_count = 0, is_pierce = false):
	var gun_projectile: PackedScene = gun.primary_projectile
	var screenshake_amount = gun.data.primary_screenshake
	var gun_sfx = gun.data.primary_sfx
	var damage = gun.data.primary_damage
	is_pierce = is_pierce or gun.data.primary_pierce
	if is_secondary:
		gun_projectile = gun.secondary_projetile
		screenshake_amount = gun.data.secondary_screenshake
		gun_sfx = gun.data.secondary_sfx
		damage = gun.data.secondary_damage
		is_pierce = is_pierce or gun.data.secondary_pierce
	play_sfx(gun_sfx)
	gun.play_muzzle_flash(is_secondary)
	var bullet_start_pos = gun.barrel.global_position
	# Randomize bullet start pos a bit
	bullet_start_pos.x += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
	bullet_start_pos.y += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
	create_hitscan_attack(bullet_start_pos, (aim_ray.aim_ray_end.global_position - bullet_start_pos), bounce_count, gun_projectile, damage, is_pierce)
	# Screenshake
	player_camera.add_trauma(screenshake_amount)
	# Recoil
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
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(3.0), delta * 5)
		elif raw_input_dir.x > 0:
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(-3.0), delta * 5)
		else:
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(0), delta * 5)

	# Lower camera
	if is_crouching:
		neck.position.y = lerp(neck.position.y, -1.0, delta * 5)
	else:
		neck.position.y = lerp(neck.position.y, 0.0, delta * 5)

func swap_gun():
	var tween = get_tree().create_tween()
	is_swapping_gun = true
	tween.tween_property(gun_container, "position:y", -0.5, SWAP_GUN_TIME).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(SWAP_GUN_TIME * 1.5).timeout
	for child: Gun in gun_container.get_children():
		child.visible = false
		child.swapped_out()
	gun_container.get_child(current_gun_slot).visible = true
	is_swapping_gun = false

func _on_dash_duration_timeout() -> void:
	is_dashing = false

func _on_grounded_state_input(event: InputEvent):
	if dialogue_active:
		return
	if event.is_action_pressed("jump"):
		jump()

func _on_grounded_state_physics_processing(_delta: float):
	if dialogue_active:
		is_crouching = false
		return
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		is_crouching = false

func _on_airborne_state_input(event: InputEvent):
	if dialogue_active:
		return
	if event.is_action_pressed("jump"):
		if can_coyote_jump and not jumped:
			jump()
		elif current_air_jump_count < max_air_jump:
			current_air_jump_count += 1
			jump()

func _on_airborne_state_entered() -> void:
	if not jumped:
		coyote_timer.start()
		can_coyote_jump = true

func _on_airborne_state_physics_processing(delta: float) -> void:
	if not is_dashing:
		vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)

func moving_toward_wall() -> bool:
	wall_raycast.target_position = Vector3(raw_input_dir.x, 0, raw_input_dir.y)
	if is_on_wall_only() and wall_raycast.is_colliding():
		return true
	return false

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
	for child in gun_container.get_children():
		if child is Gun:
			prewarm_hitscan(child.primary_projectile)
			prewarm_hitscan(child.secondary_projetile)
	prewarm_enemy_effects(get_parent())
	shot_assets_ready = true

func set_preview_mode(enabled: bool) -> void:
	preview_mode = enabled
	gun_container.visible = false
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
	is_dashing = false
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
	var capsule := $CollisionShape3D.shape as CapsuleShape3D
	var half_height := capsule.height * 0.5 if capsule != null else 1.0
	global_position.y = result.position.y + half_height + 0.01

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
