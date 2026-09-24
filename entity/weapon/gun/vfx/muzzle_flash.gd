extends AnimatedSprite3D
class_name MuzzleFlash

@onready var light: OmniLight3D = $MuzzleFlashLight
@onready var timer: Timer = $MuzzleFlashTimer

var original_light_energy

const FADE_SPEED = 8

func _ready() -> void:
    original_light_energy = light.light_energy

func _process(delta: float) -> void:
    light.light_energy = clamp(light.light_energy - FADE_SPEED * delta, 0, original_light_energy)
    modulate.a = clamp(modulate.a - FADE_SPEED * delta, 0, 1)

func flash(color: Color=Color(1.0, 0.9, 0.6)):
    modulate.a = 1
    light.light_color = color
    light.light_energy = original_light_energy
    play("default") # May be removed in future and replaced by static sprite
    var rotate_amount = randi_range(5, 45)
    rotate_z(rotate_amount)

func _on_muzzle_flash_timer_timeout() -> void:
    light.visible = false
