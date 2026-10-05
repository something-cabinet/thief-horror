extends Item
class_name Gun

const BULLET_SPAWN_POS_VARIATION = 10

@export var data: GunResource
@export var primary_projectile: PackedScene

@onready var barrel: Marker3D = $Barrel
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var firerate_timer: Timer = $FireRateTimer
@onready var muzzle_flash: MuzzleFlash = $Barrel/MuzzleFlash

var primary_projectile_color := Color.WHITE

func _ready() -> void:
    super()
    primary_projectile_color = get_projectile_color(primary_projectile)

func _on_equipped() -> void:
    reset_for_gameplay()

func _process_use_input(_delta: float) -> void:
    check_primary_attack()

func check_primary_attack():
    if Input.is_action_pressed("primary_attack"):
        if not try_primary_attack():
            return
        play_primary_attack_anim()
        perform_attack()

func perform_attack():
    var screenshake_amount = data.primary_screenshake
    player.play_sfx(data.primary_sfx)
    play_muzzle_flash()
    var bullet_start_pos = barrel.global_position
    # Randomize bullet start pos a bit
    bullet_start_pos.x += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
    bullet_start_pos.y += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
    player.create_hitscan_attack(bullet_start_pos, (player.aim_ray.aim_ray_end.global_position - bullet_start_pos), data.primary_bounce_time, primary_projectile, data.primary_damage, data.primary_pierce)
    player.apply_shot_kick(screenshake_amount)

func play_primary_attack_anim():
    anim_state_machine.start("primary_attack")

func play_idle_anim():
    anim_state_machine.travel("idle")

func reset_for_gameplay() -> void:
    firerate_timer.stop()
    play_idle_anim()
    if muzzle_flash:
        muzzle_flash.reset_flash()

func try_primary_attack(only_check=false) -> bool:
    if firerate_timer.is_stopped():
        if not only_check:
            firerate_timer.start(1.0 / data.firerate)
        return true
    return false

func play_muzzle_flash():
    if muzzle_flash:
        muzzle_flash.flash(primary_projectile_color)

func get_projectile_color(projectile_scene: PackedScene) -> Color:
    if projectile_scene == null:
        return Color.WHITE
    var projectile := projectile_scene.instantiate() as GunHitscan
    if projectile == null:
        return Color.WHITE
    var color := projectile.get_projectile_color()
    projectile.free()
    return color

func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
    play_idle_anim()
