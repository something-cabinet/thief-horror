extends Resource
class_name GunResource

@export var name: String
@export_multiline var description: String

@export_group("Stat")
## Bullet per second
@export var firerate: float
## How fast bullet travel. Ignored if is_hitscan ticked
@export var projectile_speed: float
## Bullet is not a projectiles. Shot enemy instanly damaged. If this ticked, ignore projectile_speed
@export var is_hitscan: bool

@export_group("Primary")
@export var primary_damage: int
@export var primary_sfx: AudioStream
@export var primary_bounce_time = 0
@export var primary_pierce = false
@export var primary_screenshake: float = 0

@export_group("Secondary")
@export var secondary_damage: int
@export var secondary_type: EnumAutoload.GunSecondaryAttackType
@export var secondary_sfx: AudioStream
@export var secondary_cooldown: float = 0.5
@export var secondary_charge_time: float # Not every gun use this
@export var secondary_bounce_time = 0
@export var secondary_pierce = false
@export var secondary_screenshake: float = 0
