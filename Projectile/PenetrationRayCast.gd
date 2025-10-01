extends RayCast3D

@export var OFFSET_DISTANCE: float = 0.1
@export var RAY_LENGTH: float = 5.0

#TODO: add collider selection

func measure_thickness(direction: Vector3) -> void:
	var normalized_cast_direction = direction.normalized()
	# find entry collision point
	var ray_target = normalized_cast_direction * RAY_LENGTH
	var entry_point = _find_collision(ray_target)
	push_error("Entry point: %s" % entry_point)
	
	# find exit collision point
	global_position = _get_global_offset_origin(normalized_cast_direction)
	var new_ray_target = _get_target_point(normalized_cast_direction)
	
	# if exit point was not found, move 'back' a bit and repeat
	var exit_point = _find_collision(new_ray_target)
	while exit_point == Vector3.ZERO:
		global_position = _get_global_offset_origin(normalized_cast_direction)
		exit_point = _find_collision(new_ray_target)
	
	push_error("Exit point: %s" % exit_point)
	var measured_thickness = (exit_point - entry_point).length()
	push_error("Thickness: %s" % measured_thickness)


func _get_global_offset_origin(normalized_direction: Vector3) -> Vector3:
	return global_position + normalized_direction * OFFSET_DISTANCE

func _get_target_point(normalized_direction: Vector3) -> Vector3:
	return normalized_direction * RAY_LENGTH * (-1)

func _find_collision(target: Vector3) -> Vector3:
	var collision_point: Vector3 = Vector3.ZERO;
	
	enabled = true
	target_position = to_local(target)
	force_raycast_update()
	
	if is_colliding():
		collision_point = get_collision_point();
	
	enabled = false;
	force_raycast_update()
	return collision_point;


func _get_impact_angle(projectile_direction: Vector3, surface_normal: Vector3) -> float:
	var cos_angle = abs(projectile_direction.dot(surface_normal))
	var angle_between_velocity_and_normal = acos(cos_angle)
	var contact_angle = rad_to_deg(angle_between_velocity_and_normal)
	return (90.0 - contact_angle)
	
