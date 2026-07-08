class_name BallisticProber
extends RefCounted

const RAY_LENGTH: float = 1.5
const RAY_ORIGIN_OFFSET: float = 0.01
const RAY_EXIT_ORIGIN_STEP: float = 0.25

static func probe_thickness(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int = 4294967295 								# TODO: By default checks all layers - switch later
) -> float:
	
	var entry_result = _find_entry_point(space_state, origin_point, direction_normalized, collision_mask)
	
	print("\nThickness probe:")
	print("Origin point: ", origin_point)
	print("Direction normalized: ", direction_normalized)
	print("Ray length: ", RAY_LENGTH)
	print("End point: ", origin_point + direction_normalized * RAY_LENGTH)
	
	if not entry_result.is_empty():
		var entry_point: Vector3 = entry_result.position
		var target_collider: CollisionObject3D = entry_result.collider
		var exit_point_optional = _find_exit_point(space_state, entry_point, target_collider, direction_normalized, collision_mask)
		
		if not exit_point_optional.is_empty():
			var exit_point: Vector3 = exit_point_optional[0]
			var thickness = (exit_point - entry_point).length()
			
			print("Thickness: ", thickness)
			
			return thickness
		else:
			push_error("Exit collision not found for collider %s" % target_collider.name)
	else:    
		push_error("Entry collision not found")
		
	return 0.0

static func _find_entry_point(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int
	) -> Dictionary:
	
	var start_point = origin_point - direction_normalized * RAY_ORIGIN_OFFSET
	var end_point = origin_point + direction_normalized * RAY_LENGTH
	var query_entry = PhysicsRayQueryParameters3D.create(start_point, end_point)
	return space_state.intersect_ray(query_entry)


static func _find_exit_point(
	space_state: PhysicsDirectSpaceState3D,
	entry_point: Vector3,
	target_collider: CollisionObject3D,
	direction_normalized: Vector3,
	collision_mask: int
) -> Array[Vector3]:
	
	var exclusion_list: Array[RID] = []
	var start_point_exit = entry_point + direction_normalized * RAY_EXIT_ORIGIN_STEP
	var end_point_exit = entry_point - direction_normalized * RAY_LENGTH
	
	while(true):
		var query_exit = PhysicsRayQueryParameters3D.create(start_point_exit, end_point_exit)
		query_exit.exclude = exclusion_list
		var result = space_state.intersect_ray(query_exit)
		
		if result.size() > 0: # Check if detected collision was the one expected
			var exit_collider: CollisionObject3D = result.collider
			if exit_collider == target_collider:
				return [result.position] 
			else: # Exclude unwanted collider and check again
				var unwanted_rid: RID = exit_collider.get_rid()
				exclusion_list.append(unwanted_rid)
				
		
		else: # If no detection found in this sweep, move the ray origin-target further
			var max_search_offset = RAY_LENGTH * 5
			var current_offset = (start_point_exit - (entry_point + direction_normalized * RAY_EXIT_ORIGIN_STEP)).length()
			if current_offset > max_search_offset:
				break 
				
			# Move the start/end points further away
			start_point_exit = start_point_exit + direction_normalized * RAY_EXIT_ORIGIN_STEP
			end_point_exit = end_point_exit - direction_normalized * RAY_LENGTH
	
	return []
