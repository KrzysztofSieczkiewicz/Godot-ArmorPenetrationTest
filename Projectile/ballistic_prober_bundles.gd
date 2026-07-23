class_name BallisticProberBundles
extends RefCounted

const RAY_LENGTH: float = 1.5
const RAY_ORIGIN_OFFSET: float = 0.002
const RAY_EXIT_ORIGIN_STEP: float = 0.25


class ArmorProbingPacket:
	var entry_point: Vector3
	var exit_point: Vector3
	var thickness: float



static func probe_main_ray() -> void:
	pass


static func probe_secondary_rays() -> void:
	pass
	
## TODO: rework the return type and structure
static func get_collisions_along_path(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int,
	collision_gap_threshold: float, 			## Distance between colliders surfaces above which collision group is separated
	ray_offset: float,
) -> Array[Dictionary]:
	var collision_groups: Array[Dictionary] = []
	var current_origin = origin_point
	var ray_position_epsilon = 0.005
	
	while true:
		# 1. Find entry point
		var entry_result = _find_entry_point(
				space_state, 
				origin_point, 
				direction_normalized, 
				collision_mask,
		)
		
		# EARLY EXIT - no more colliders
		if entry_result.is_empty():
			break 
		
		var entry_pos: Vector3 = entry_result.position
		var exit_pos: Vector3 = entry_pos
		var target_collider: CollisionObject3D = entry_result.collider
		
		# 2. Find exit point
		var exit_result = _find_exit_point(
			space_state, 
			entry_pos, 
			target_collider, 
			direction_normalized, 
			collision_mask
		)
		
		# EARLY EXIT - no exit found
		if exit_result == Vector3.INF:
			break 
		else:
			exit_pos = exit_result
		
		if collision_groups.is_empty():
			collision_groups.append({
				"entry": entry_pos,
				"exit": exit_pos,
				"colliders": [target_collider],
			})
		else:
			var last_group = collision_groups.back()
			var gap = entry_pos.distance_to(last_group["exit"])
			
			if gap <= collision_gap_threshold:
				last_group["exit"] = exit_pos
				if not last_group["colliders"].has(target_collider):
					last_group["colliders"].append(target_collider)
			else:
				collision_groups.append({
					"entry": entry_pos,
					"exit": exit_pos,
					"colliders": [target_collider],
				})
		
		current_origin = exit_pos + (direction_normalized * ray_position_epsilon)
	
	return collision_groups
	
	# find entry point
	# find exit point
	# is there another entry point within length distance_threshold
	#	if yes -> repeat and add to the result array
	#	if not -> return the array
	
	"""
	Find an entry point, and search for exit surface:
		assume surface is exit if there is at least 1cm gap
		assume collision group is done when the gap is at least shell length
	"""

static func probe_thickness(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int = 4294967295 								# TODO: Not used at all - find a way later (might be better to just accept RID of the target collider as an arg)
) -> ArmorProbingPacket:
	var probing_result = ArmorProbingPacket.new()
	var entry_result = _find_entry_point(space_state, origin_point, direction_normalized, collision_mask)
	
	if not entry_result.is_empty():
		probing_result.entry_point = entry_result.position
		var target_collider: CollisionObject3D = entry_result.collider
		var exit_point_optional = _find_exit_point(space_state, probing_result.entry_point, target_collider, direction_normalized, collision_mask)
		
		if not exit_point_optional.is_empty():
			probing_result.exit_point = exit_point_optional[0]
			probing_result.thickness = (probing_result.exit_point - probing_result.entry_point).length()
			
			return probing_result
		else:
			push_error("Exit collision not found for collider %s" % target_collider.name)
	else:    
		push_error("Entry collision not found")
	
	return probing_result


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


static func _find_exit_point(														# TODO: both inefficient and might be working wrong with more complex colliders
	space_state: PhysicsDirectSpaceState3D,
	entry_point: Vector3,
	target_collider: CollisionObject3D,
	direction_normalized: Vector3,
	collision_mask: int
) -> Vector3:
	
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
				return result.position
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
	
	return Vector3.INF
