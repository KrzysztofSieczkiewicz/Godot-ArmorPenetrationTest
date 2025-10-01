extends RayCast3D

@export var OFFSET_DISTANCE = 0.01
@export var RAY_LENGTH = 500.0


func measure_thickness(origin: Vector3, direction: Vector3) -> void:
	var target = direction.normalized() * RAY_LENGTH
	var entry_point = _find_collision_point(origin, target)
	push_error("Entry point: %s" % entry_point)
	
	var new_origin = _offset_origin(entry_point, direction)
	var new_target = _get_opposite_target(entry_point, direction)
	
	var exit_point = _find_collision_point(new_origin, new_target)
	
	while exit_point == Vector3.ZERO:
		new_origin = _offset_origin(new_origin, direction)
		exit_point = _find_collision_point(new_origin, new_target)
		push_warning("Trying further away")
	
	push_error("Exit point: %s" % exit_point)
	
	var measured_thickness = (exit_point - entry_point).length()
	push_error("Thickness: %s" % measured_thickness)


func _offset_origin(origin: Vector3, direction: Vector3) -> Vector3:
	var normalized: Vector3 = direction.normalized()
	return origin + normalized * OFFSET_DISTANCE


func _get_opposite_target(origin: Vector3, direction: Vector3) -> Vector3:
	return origin + direction.normalized() * (-1) * RAY_LENGTH


func _find_collision_point(origin: Vector3, target: Vector3) -> Vector3:
	var collision_point: Vector3 = Vector3.ZERO;
	
	enabled = true
	global_position = origin
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
	
