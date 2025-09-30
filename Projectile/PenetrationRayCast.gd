extends RayCast3D

@export var OFFSET_DISTANCE = 0.01
@export var RAY_LENGTH = 500.0


func measure_thickness(origin: Vector3, direction: Vector3) -> void:
	_find_entry_point(origin, direction)


func _find_entry_point(origin: Vector3, direction: Vector3) -> void:
	enabled = true
	target_position = direction * RAY_LENGTH 
	force_raycast_update()
	
	var entry_point: Vector3 = get_collision_point()
	var contact_surface_normal: Vector3 = get_collision_normal()
	
	var OFFSET: float = 50.0;
	var collision_vector = direction
	var new_position = entry_point + direction * OFFSET
	var new_direction = collision_vector.normalized() * (-1) * OFFSET
	var new_target_position = new_position + new_direction * RAY_LENGTH
	
	var contact_angle = _get_impact_angle(direction, contact_surface_normal)
	
	global_transform.origin = new_position
	target_position = to_local(new_target_position)
	force_raycast_update()
	
	var exit_point: Vector3 = get_collision_point()
	
	var thickness = (exit_point - entry_point).length()
	push_error("Thickness: %s" % thickness)


func _get_impact_angle(projectile_direction: Vector3, surface_normal: Vector3) -> float:
	var cos_angle = abs(projectile_direction.dot(surface_normal))
	var angle_between_velocity_and_normal = acos(cos_angle)
	var contact_angle = rad_to_deg(angle_between_velocity_and_normal)
	return (90.0 - contact_angle)
	
