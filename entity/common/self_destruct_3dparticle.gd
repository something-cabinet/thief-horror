extends GPUParticles3D

func _ready():
	emitting = true

func _on_finished():
	call_deferred("queue_free")
