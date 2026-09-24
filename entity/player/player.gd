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
@onready var aim_ray: AimRay = $Neck/ShakeableCamera/AimRay
@onready var aim_reticle: TextureRect = $Neck/ShakeableCamera/AimRecticle
@onready var hitmarker: TextureRect = $Neck/ShakeableCamera/HitMarker
@onready var pause_ui: PauseUI = $CanvasLayer/PauseUI

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
const HITSCAN_COLLISION_MASK = 3
const HITSCAN_SURFACE_OFFSET = 0.01
const MIN_STEP_HEIGHT = 0.05
const STEP_TEST_MARGIN = 0.002
const STEP_CLEARANCE = 0.005
const STEP_SEAM_TOLERANCE = 0.02
const STEP_PROBE_INCREMENT = 0.05
const STEP_LANDING_MIN_UP_DOT = 0.5
const STUCK_LOG_INTERVAL_MSEC = 500
const STUCK_MIN_REQUEST_DISTANCE = 0.005
const STUCK_PROGRESS_RATIO = 0.15

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

func _ready():
	GameManager.player = self
	player_camera.set_fov(GameManager.camera_fov)
	player_camera.rotation_degrees.x = initial_camera_pitch_degrees
	if not GameManager.is_preparing_first_level:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	gun_container_original_pos = gun_container.position
	last_dashed_timestamp = 0
	current_gun_slot = 0
	for child in gun_container.get_children():
		child.visible = false
	gun_container.get_child(current_gun_slot).visible = true
	call_deferred("prewarm_shot_assets")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			debug_label.visible = not debug_label.visible
			get_viewport().set_input_as_handled()
			return
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
	if not attack_input_armed:
		attack_input_armed = (
			not Input.is_action_pressed("primary_attack")
			and not Input.is_action_pressed("secondary_attack")
		)
		return
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
			if landing_sfx_armed:
				if vel_vertical < -FALL_SPEED_TO_SHAKE_CAMERA:
					player_camera.add_trauma(HEAVY_FALL_SHAKE_TRAUMA)
				play_sfx(landing_sfx)
			jumped = false
			vel_vertical = 0
		landing_sfx_armed = true
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
	var movement_start := global_position
	var requested_horizontal_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	is_step_traversing = false
	var step_handled := _try_step_up(requested_horizontal_motion)
	if not step_handled:
		move_and_slide()

	if debug_label.visible:
		_log_stuck_movement(movement_start, requested_horizontal_motion)
		show_debug_label()

	var gun_sway_velocity = velocity * transform.basis
	if not is_swapping_gun:
		gun_container.position = lerp(gun_container.position, gun_container_original_pos - (gun_sway_velocity / 500), delta * 10)
	camera_control(delta)


func _try_step_up(horizontal_motion: Vector3) -> bool:
	if not is_on_floor() or jumped or velocity.y > 0.0:
		step_debug_reason = "not grounded"
		return false

	if horizontal_motion.length_squared() < 0.000001:
		step_debug_reason = "no horizontal motion"
		return false

	var start_transform := global_transform
	var obstacle_collision := KinematicCollision3D.new()
	if not test_move(start_transform, horizontal_motion, obstacle_collision):
		step_debug_reason = "no obstacle"
		return false
	if obstacle_collision.get_collision_count() == 0:
		step_debug_reason = "obstacle without contact"
		return false
	var obstacle_normal := obstacle_collision.get_normal()
	var obstacle_is_walkable := obstacle_normal.dot(Vector3.UP) >= cos(floor_max_angle)

	# Test the complete player shape, not a ray or a map-specific ramp. Try the
	# maximum legal rise first, then smaller lifts for low door headers/seams.
	var maximum_lift := max_step_height + STEP_CLEARANCE
	var lift_distances: Array[float] = [maximum_lift, STEP_SEAM_TOLERANCE + STEP_CLEARANCE]
	var probe_height := MIN_STEP_HEIGHT
	while probe_height < max_step_height - STEP_TEST_MARGIN:
		lift_distances.append(probe_height + STEP_CLEARANCE)
		probe_height += STEP_PROBE_INCREMENT

	var last_rejection := "no valid landing"
	for lift_distance: float in lift_distances:
		var raised_transform := start_transform
		var up_motion := Vector3.UP * lift_distance
		if test_move(start_transform, up_motion):
			last_rejection = "blocked headroom at %.3f" % lift_distance
			continue
		raised_transform.origin += up_motion

		var raised_forward_transform := raised_transform
		var forward_collision := KinematicCollision3D.new()
		if test_move(raised_transform, horizontal_motion, forward_collision):
			last_rejection = "raised path blocked at %.3f" % lift_distance
			# If the body cannot move forward at the maximum legal rise, the
			# obstacle is a wall/tall object unless the contact is an overhead
			# surface. Smaller probes can pass below a low stairwell ceiling.
			var forward_normal := forward_collision.get_normal(0)
			if (
				is_equal_approx(lift_distance, maximum_lift)
				and not obstacle_is_walkable
				and forward_normal.y >= -STEP_TEST_MARGIN
			):
				break
			continue
		raised_forward_transform.origin += horizontal_motion

		var down_motion := Vector3.DOWN * (lift_distance + floor_snap_length)
		var down_collision := KinematicCollision3D.new()
		if not test_move(raised_forward_transform, down_motion, down_collision):
			last_rejection = "no landing at %.3f" % lift_distance
			continue
		if down_collision.get_collision_count() == 0:
			last_rejection = "landing without contact"
			continue

		var landing_normal := down_collision.get_normal(0)
		# The capsule's rounded foot initially meets a stair nose diagonally.
		# A full-height wall remains blocked during the raised forward sweep.
		if landing_normal.dot(Vector3.UP) < STEP_LANDING_MIN_UP_DOT:
			last_rejection = "landing not walkable normal=%s" % landing_normal
			continue

		var landing_position := raised_forward_transform.origin + down_collision.get_travel()
		var step_height := landing_position.y - start_transform.origin.y
		var crosses_floor_seam := (
			obstacle_is_walkable
			and absf(step_height) <= STEP_SEAM_TOLERANCE
		)
		if (
			(not crosses_floor_seam and step_height < MIN_STEP_HEIGHT)
			or step_height > max_step_height + STEP_TEST_MARGIN
		):
			last_rejection = "landing height %.3f outside range" % step_height
			continue

		global_position = landing_position
		vel_vertical = 0.0
		velocity.y = 0.0
		is_step_traversing = true
		# Keep the view at its pre-step height; camera_control() eases it onto
		# the new floor while the body is already safely supported.
		if step_height >= MIN_STEP_HEIGHT:
			neck.position.y -= step_height
		step_debug_reason = "%s height=%.3f lift=%.3f" % [
			"crossed floor seam" if crosses_floor_seam else "accepted",
			step_height,
			lift_distance,
		]
		return true

	step_debug_reason = last_rejection
	return false


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
		+ "requested=(%.3f, %.3f) actual=%.4f on_floor=%s step=%s "
		+ "step_result=\"%s\" pitch_deg=%.1f yaw_deg=%.1f blocker=%s "
		+ "contact=(%.3f, %.3f, %.3f) normal=(%.3f, %.3f, %.3f)"
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
	if GameManager.is_preparing_first_level:
		await render_prewarmed_shot_assets()
	shot_assets_ready = true

func set_preview_mode(enabled: bool) -> void:
	gun_container.visible = not enabled
	aim_reticle.visible = not enabled
	hitmarker.visible = not enabled
	debug_label.visible = false
	pause_ui.visible = false
	pause_ui.is_paused = false
	pause_ui.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_ALWAYS
	if not enabled:
		attack_input_armed = false
		for child in gun_container.get_children():
			if child is Gun:
				child.reset_for_gameplay()

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
