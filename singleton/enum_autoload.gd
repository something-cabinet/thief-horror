extends Node

enum GunSecondaryAttackType {
	NONE,
	CLICK_ATTACK, # ex: Shoot a strong beam once
	CLICK_NONATTACK, # ex: Buff primary / ADS
	HOLD, # ex: Use a shield / shooting lots of bullets
	HOLD_AND_RELEASE, # ex: Charge a powerful beam and shoot
	ADS # Aim down sight
}

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(2560, 1440),
	Vector2i(1920, 1080),
	Vector2i(1440, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(1024, 768),
]

var FPS_LIMIT_ARRAY = [30, 60, 120, 144, 240, 0]
var RESOLUTION_ARRAY: Array[Vector2i] = RESOLUTION_PRESETS.duplicate()


func configure_resolutions(maximum_size: Vector2i, recommended_size: Vector2i) -> int:
	RESOLUTION_ARRAY.clear()
	RESOLUTION_ARRAY.append(recommended_size)
	for resolution in RESOLUTION_PRESETS:
		if resolution.x <= maximum_size.x and resolution.y <= maximum_size.y and resolution != recommended_size:
			RESOLUTION_ARRAY.append(resolution)
	return 0
