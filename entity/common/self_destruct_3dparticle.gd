extends GPUParticles3D
class_name SelfDestruct3DParticle

signal released(effect: SelfDestruct3DParticle)

var pool_managed := false

func _ready():
	if pool_managed:
		prepare_for_pool()
	else:
		activate()

func activate() -> void:
	visible = true
	emitting = true
	restart()

func prepare_for_pool() -> void:
	emitting = false
	visible = false

func _on_finished():
	if pool_managed:
		prepare_for_pool()
		released.emit(self)
	else:
		call_deferred("queue_free")
