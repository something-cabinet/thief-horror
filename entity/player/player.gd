extends CharacterBody3D
class_name Player

@export var max_air_jump = 2
@export var dash_cd: float = 0.5
@export var aim_ray_prefab: PackedScene

@onready var player_camera: ShakeableCamera = $Neck/ShakeableCamera
@onready var debug_label: Label = $Neck/ShakeableCamera/DebugLabel
@onready var dash_duration_timer: Timer = $DashDuration
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var neck: Node3D = $Neck
@onready var state_chart: StateChart = $StateChart
@onready var wall_raycast: RayCast3D = $WallRaycast
@onready var audio_player: CharacterAudioPlayer3D = $CharacterAudioPlayer3D

@onready var gun_container = $Neck/ShakeableCamera/GunContainer
@onready var aim_ray: AimRay = $Neck/ShakeableCamera/AimRay
@onready var hitmarker: TextureRect = $Neck/ShakeableCamera/HitMarker

var landing_sfx = preload("res://asset/sfx/player/jump_landing.wav")

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

func _ready():
	GameManager.player = self
	player_camera.set_fov(GameManager.camera_fov)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	gun_container_original_pos = gun_container.position
	last_dashed_timestamp = 0
	current_gun_slot = 0
	for child in gun_container.get_children():
		child.visible = false
	gun_container.get_child(current_gun_slot).visible = true

func _input(event):
	if event is InputEventMouseMotion:
		rotate_player(event)
	if event.is_action_pressed("dash"):
		if last_dashed_timestamp + dash_cd * 1000 <= Time.get_ticks_msec():
			last_dashed_timestamp = Time.get_ticks_msec()
			is_dashing = true
			vel_vertical = 0
			dash_duration_timer.start()
	if event.is_action_pressed("weapon_slot_1") and current_gun_slot != 0:
		current_gun_slot = 0
		swap_gun()
	if event.is_action_pressed("weapon_slot_2") and current_gun_slot != 1:
		current_gun_slot = 1
		swap_gun()

func _process(delta):
	hitmarker.modulate.a = clamp(hitmarker.modulate.a - delta * 3, 0, 1)
	if not is_swapping_gun:
		check_primary_attack()
		check_secondary_attack()

func _physics_process(delta):
	if is_dashing:
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
			if vel_vertical < -FALL_SPEED_TO_SHAKE_CAMERA:
				player_camera.add_trauma(HEAVY_FALL_SHAKE_TRAUMA)
			play_sfx(landing_sfx)
			jumped = false
			vel_vertical = 0
	else:
		state_chart.send_event("airborne")

	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and raw_input_dir != Vector2.ZERO
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
	move_and_slide()

	show_debug_label()

	var gun_sway_velocity = velocity * transform.basis
	if not is_swapping_gun:
		gun_container.position = lerp(gun_container.position, gun_container_original_pos - (gun_sway_velocity / 500), delta * 10)
	camera_control(delta)

func play_sfx(sfx: AudioStream):
	audio_player.play(sfx, "SFX", true)

func show_debug_label():
	var h_speed = snapped(Vector3(velocity.x, 0, velocity.z).length(), 0.1)
	var v_speed = snapped(vel_vertical, 0.1)
	var snapped_height = snapped(global_position.y, 0.1)
	Engine.get_frames_per_second()
	debug_label.text = ""
	debug_label.text += "FPS: {0}".format([Engine.get_frames_per_second()])
	debug_label.text += "\nHSpeed: {0} u/s\nVSpeed: {1} u/s".format([h_speed, v_speed])
	debug_label.text += "\nHeight from ground: {0}".format([snapped_height - 1.5])
	debug_label.text += "\nOn ground: {0} | wall-cling: {1}".format([is_on_floor(), moving_toward_wall()])
	debug_label.text += "\nIs dashing: {0} | Is crouching: {1} | Is sprinting: {2}".format([is_dashing, is_crouching, is_sprinting])
	debug_label.text += "\nAir jumps left: {0}".format([max_air_jump - current_air_jump_count])
	debug_label.text += "\nCoyote jump: {0}".format([can_coyote_jump])
	debug_label.text += "\nUsing gun: {0}".format([gun_container.get_child(current_gun_slot).data.name])

func jump(multiplier = 1.0):
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

func perform_attack(gun: Gun, is_secondary: bool = false, bounce_count = 0, _is_pierce = false):
	var gun_projectile: PackedScene = gun.primary_projectile
	var screenshake_amount = gun.data.primary_screenshake
	var gun_sfx = gun.data.primary_sfx
	var damage = gun.data.primary_damage
	if is_secondary:
		gun_projectile = gun.secondary_projetile
		screenshake_amount = gun.data.secondary_screenshake
		gun_sfx = gun.data.secondary_sfx
		damage = gun.data.secondary_damage
	play_sfx(gun_sfx)
	gun.play_muzzle_flash(is_secondary)
	var bullet_start_pos = gun.barrel.global_position
	# Randomize bullet start pos a bit
	bullet_start_pos.x += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
	bullet_start_pos.y += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
	create_hitscan_attack(bullet_start_pos, (aim_ray.aim_ray_end.global_position - bullet_start_pos), bounce_count, gun_projectile, damage)
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
	if event.is_action_pressed("jump"):
		jump()

func _on_grounded_state_physics_processing(_delta: float):
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		is_crouching = false

func _on_airborne_state_input(event: InputEvent):
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

func create_hitscan_attack(start_pos: Vector3, direction: Vector3, bounce_left: int, gun_projectile: PackedScene, damage: int):
	var hitscan_ray: AimRay = aim_ray_prefab.instantiate()
	get_parent().add_child(hitscan_ray)
	hitscan_ray.global_position = start_pos
	hitscan_ray.look_at(start_pos + direction)
	var bullet_inst: BaseProjectile = gun_projectile.instantiate()

	await get_tree().physics_frame
	await get_tree().physics_frame
	if hitscan_ray.is_colliding():
		var hitscan_col_point = hitscan_ray.get_collision_point()
		var hitscan_col_normal = hitscan_ray.get_collision_normal()
		bullet_inst.init(start_pos, hitscan_col_point)
		get_parent().add_child(bullet_inst)
		if hitscan_ray.get_collider() is Enemy:
			var enemy: Enemy = hitscan_ray.get_collider()
			var killed = enemy.damaged(damage)
			if killed:
				flash_hitmarker(Color.RED)
			else:
				flash_hitmarker()
			enemy.play_on_damaged_effect(hitscan_col_point, hitscan_col_normal)
		else:
			# Hit wall/obstacle
			bullet_inst.create_spark(hitscan_col_point, hitscan_col_normal)

		if bounce_left > 0:
			create_hitscan_attack(hitscan_col_point, direction.bounce(hitscan_col_normal), bounce_left - 1, gun_projectile, damage)
	else:
		bullet_inst.init(start_pos, hitscan_ray.aim_ray_end.global_position)
		get_parent().add_child(bullet_inst)
	hitscan_ray.call_deferred("queue_free")

func _on_coyote_timer_timeout():
	can_coyote_jump = false
