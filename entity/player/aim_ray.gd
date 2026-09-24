extends RayCast3D
class_name AimRay

@onready var aim_ray_end: Marker3D = $AimRayEnd
@onready var box_cast: ShapeCast3D = $AimRayBoxCast

func change_boxcast_thickness(value: float):
    box_cast.shape.x = value
    box_cast.shape.y = value