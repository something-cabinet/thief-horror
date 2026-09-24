extends Node3D
class_name Gun

@export var data: GunResource
@export var primary_projectile: PackedScene
@export var secondary_projetile: PackedScene

@onready var barrel: Marker3D = $Barrel
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var firerate_timer: Timer = $FireRateTimer
@onready var secondary_timer: Timer = $SecondaryTimer
@onready var muzzle_flash: MuzzleFlash = $Barrel/MuzzleFlash

var start_charge_timestamp = 0
var is_charging = false

func play_primary_attack_anim():
    anim_state_machine.start("primary_attack")

func play_secondary_attack_anim():
    anim_state_machine.travel("secondary_attack")

func play_secondary_attack_hold_anim():
    anim_state_machine.travel("secondary_attack_hold")

func play_secondary_attack_release_anim():
    anim_state_machine.travel("secondary_attack_release")

func play_idle_anim():
    anim_state_machine.travel("idle")

func try_primary_attack(only_check=false) -> bool:
    if firerate_timer.is_stopped() and not is_charging:
        if not only_check:
            firerate_timer.start(1.0 / data.firerate)
        return true
    return false

func try_secondary_attack(only_check=false) -> bool:
    if secondary_timer.is_stopped():
        if not only_check:
            secondary_timer.start(data.secondary_cooldown)
        return true
    return false

func play_muzzle_flash(is_secondary_attack=false):
    if muzzle_flash:
        var tmp: GunHitscan
        if not is_secondary_attack:
            tmp = primary_projectile.instantiate()
        else:
            tmp = secondary_projetile.instantiate()
        var light_color = tmp.get_projectile_color()
        muzzle_flash.flash(light_color)
        tmp.queue_free()

func check_if_animation_playing(anim_name: String):
    return anim_state_machine.get_current_node() == anim_name

func start_charge():
    start_charge_timestamp = Time.get_ticks_msec()
    is_charging = true

# How long secondary has been hold down
func release_charge():
    is_charging = false
    if start_charge_timestamp + data.secondary_charge_time * 1000 <= Time.get_ticks_msec():
        return true
    return false

func swapped_out():
    release_charge()
    play_idle_anim()

func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
    play_idle_anim()
