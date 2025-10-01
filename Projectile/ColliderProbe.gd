extends Node3D

@export var RAY_LENGTH: float = 1.5
@export var RAY_ORIGIN_OFFSET: float = 0.5


func probe_thickness(normalized_direction: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	
	# 1. Find the entry point
	var entry_result = _find_entry_point(space_state, normalized_direction)
	
	if entry_result.size() > 0:
		var entry_point: Vector3 = entry_result.position
		var target_collider: CollisionObject3D = entry_result.collider
		
		# 2. Find the exit point
		var exit_point_optional = _find_exit_point(space_state, entry_point, target_collider, normalized_direction)
		
		if exit_point_optional.size() > 0:
			var exit_point: Vector3 = exit_point_optional[0] # The single element in the array
			
			# 3. Calculate and report thickness
			var thickness = (exit_point - entry_point).length()
			push_warning("Thickness %s" % thickness)
		else:
			push_error("Exit collision not found for collider %s" % target_collider.name)
	else:	
		push_error("Entry collision not found")


func _find_entry_point(space_state: PhysicsDirectSpaceState3D, normalized_direction: Vector3) -> Dictionary:
	var start_point_entry = global_position
	var end_point_entry = global_position + normalized_direction * RAY_LENGTH
	
	var query_entry = PhysicsRayQueryParameters3D.create(start_point_entry, end_point_entry)
	return space_state.intersect_ray(query_entry)


func _find_exit_point(space_state: PhysicsDirectSpaceState3D, entry_point: Vector3, target_collider: CollisionObject3D, normalized_direction: Vector3) -> Array[Vector3]:
	var exclusion_list: Array[RID] = []
	var start_point_exit = entry_point + normalized_direction * RAY_ORIGIN_OFFSET
	var end_point_exit = entry_point - normalized_direction * RAY_LENGTH
	
	while(true):
		# Create and execute the raycast query
		var query_exit = PhysicsRayQueryParameters3D.create(start_point_exit, end_point_exit)
		query_exit.exclude = exclusion_list
		var result2 = space_state.intersect_ray(query_exit)
		
		if result2.size() > 0:
			# Check if detected collision was the one expected
			var exit_collider: CollisionObject3D = result2.collider
			if exit_collider == target_collider:
				return [result2.position]
			# Exclude unwanted collider and shoot again
			else:
				var unwanted_rid: RID = exit_collider.get_rid()
				exclusion_list.append(unwanted_rid)
				
		# If no detection found in this sweep, move the ray origin/target.
		else:
			var max_search_offset = RAY_LENGTH * 5
			var current_offset = (start_point_exit - (entry_point + normalized_direction * RAY_ORIGIN_OFFSET)).length()
			if current_offset > max_search_offset:
				break 
				
			# Move the start/end points further away
			start_point_exit = start_point_exit + normalized_direction * RAY_ORIGIN_OFFSET
			end_point_exit = end_point_exit - normalized_direction * RAY_LENGTH

	return []
