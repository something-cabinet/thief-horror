extends CharacterBody3D
class_name Enemy

@export var data: EnemyResource
@export var bloodsplatter: PackedScene

var current_hp: int
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready():
	current_hp = data.max_hp

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move_dir = Vector2(0, 0)
	var direction = (transform.basis * Vector3(move_dir.x, 0, move_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()

## Return true if this kill enemy
func damaged(value: int) -> bool:
	current_hp = clamp(current_hp - value, 0, data.max_hp)
	if current_hp <= 0:
		dead()
		return true
	return false

func play_on_damaged_effect(pos: Vector3, normal: Vector3):
	var bs_inst = bloodsplatter.instantiate()
	get_parent().add_child(bs_inst)
	bs_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		bs_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		bs_inst.rotation_degrees.x = 90
	else:
		bs_inst.look_at(pos + normal, Vector3.UP)

func dead():
	call_deferred("queue_free")
