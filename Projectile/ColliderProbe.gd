extends Node3D

@export var RAY_LENGTH: float = 1.5
@export var RAY_ORIGIN_OFFSET: float = 0.5

func probe_thickness(normalized_direction: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	
	# prepare entry ray origin and target
	var start_point_entry = global_position
	var end_point_entry = global_position + normalized_direction * RAY_LENGTH
	
	# init and execute entry ray query
	var query_entry = PhysicsRayQueryParameters3D.create(start_point_entry, end_point_entry)
	var result1 = space_state.intersect_ray(query_entry)
	
	if result1.size() > 0:
		var entry_point = result1.position
		# save the collider to know which exit ray collision is the correct one
		var target_collider: CollisionObject3D = result1.collider
		
		# prepare exit ray origin and target
		var start_point_exit = entry_point + normalized_direction * RAY_ORIGIN_OFFSET
		var end_point_exit = entry_point - normalized_direction * RAY_LENGTH
		
		var is_valid_exit_point = false;
		var exclusion_list: Array[RID] = []
		var exit_point: Vector3
		while(not is_valid_exit_point):
			# init and execute exit ray query
			var query_exit = PhysicsRayQueryParameters3D.create(start_point_exit, end_point_exit)
			query_exit.exclude = exclusion_list
			var result2 = space_state.intersect_ray(query_exit)
			
			if result2.size() > 0:
				# check if detected collision was the one expected
				var exit_collider: CollisionObject3D = result2.collider
				if exit_collider == target_collider:
					is_valid_exit_point = true
					exit_point = result2.position
				# if not, exclude collider and shoot again
				else:
					var unwanted_rid: RID = exit_collider.get_rid()
					exclusion_list.append(unwanted_rid) 
					
			#if no detections were found, move away and shoot again
			else:
				start_point_exit = start_point_exit + normalized_direction * RAY_ORIGIN_OFFSET
				end_point_exit = end_point_exit - normalized_direction * RAY_LENGTH
		
		var thickness = (exit_point - entry_point).length()
		push_warning("Thickness %s" % thickness)
	else: 
		push_error("Entry collision not found")
