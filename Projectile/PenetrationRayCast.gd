extends RayCast3D

@export var OFFSET_DISTANCE = 0.01
@export var RAY_LENGTH = 500.0

@onready var ray_cast: RayCast3D = $RayCast3D


func measure_thickness(collision_angle: float) -> void:
	pass

func _find_entry_point(origin: Vector3, direction: Vector3) -> void:
	enabled = true
	target_position = direction * RAY_LENGTH 
	force_raycast_update()
	
	if not is_colliding():
		enabled = false
		push_warning("Ray did not hit the mesh.")
		return
	
	var entry_point: Vector3 = get_collision_point()
	var entry_normal: Vector3 = get_collision_normal()
