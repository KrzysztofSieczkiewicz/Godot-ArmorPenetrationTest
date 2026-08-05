class_name BallisticProberBundles
extends RefCounted

const RAY_LENGTH: float = 1.5
const RAY_ORIGIN_OFFSET: float = 0.002

class ArmorProbingPacket:
	var entry_point: Vector3
	var exit_point: Vector3
	var thickness: float

class ColliderProbingResult:
	var entry_point: Vector3
	var exit_point: Vector3
	var collider: RID

class CollisionGroupProbingResult:
	var entry_point: Vector3
	var exit_point: Vector3
	var colliders: Array[ColliderProbingResult]


static func probe_main_ray() -> void:
	pass


static func probe_secondary_rays() -> void:
	pass


"""
	Find an entry point, and search for exit surface:
	assume surface is exit if there is at least X-width gap
	assume collision group is done when the gap is at least shell length (are You sure?)
"""
	
static func get_collisions_along_path(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int,
	collision_gap_threshold: float, 			## Distance between colliders surfaces above which collision group is separated
) -> Array[Dictionary]:
	var collision_groups: Array[Dictionary] = []
	var current_origin = origin_point
	
	while true:
		# 1. Find entry point
		var entry_result = _find_entry_data(
				space_state, 
				current_origin, 
				direction_normalized,
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
			direction_normalized, 
			target_collider
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
				"collisions": [target_collider],
			})
		else:
			var last_group = collision_groups.back()
			var gap = entry_pos.distance_to(last_group["exit"])
			
			if gap <= collision_gap_threshold:
				last_group["exit"] = exit_pos
				if not last_group["collisions"].has(target_collider):
					last_group["collisions"].append(target_collider)
			else:
				collision_groups.append({
					"entry": entry_pos,
					"exit": exit_pos,
					"collisions": [target_collider],
				})
		
		current_origin = exit_pos + (direction_normalized * RAY_ORIGIN_OFFSET)
	
	return collision_groups


static func probe_collisions() -> void:
	pass


static func probe_thickness(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	collision_mask: int = 4294967295 								# TODO: Not used at all - find a way later (might be better to just accept RID of the target collider as an arg)
) -> ArmorProbingPacket:
	var probing_result = ArmorProbingPacket.new()
	var entry_result = _find_entry_data(space_state, origin_point, direction_normalized)
	
	if not entry_result.is_empty():
		probing_result.entry_point = entry_result.position
		var target_collider: CollisionObject3D = entry_result.collider
		var exit_point_optional = _find_exit_point(space_state, probing_result.entry_point, direction_normalized, target_collider)
		
		if not exit_point_optional.is_empty():
			probing_result.exit_point = exit_point_optional[0]
			probing_result.thickness = (probing_result.exit_point - probing_result.entry_point).length()
			
			return probing_result
		else:
			push_error("Exit collision not found for collider %s" % target_collider.name)
	else:    
		push_error("Entry collision not found")
	
	return probing_result


static func _find_entry_data(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	direction_normalized: Vector3,
	) -> Dictionary:
	var offset_origin_point = origin_point - direction_normalized * RAY_ORIGIN_OFFSET
	var offset_end_point = origin_point + direction_normalized * RAY_LENGTH
	var query_entry = PhysicsRayQueryParameters3D.create(offset_origin_point, offset_end_point)
	query_entry.hit_back_faces = false
	
	return space_state.intersect_ray(query_entry)


static func _find_exit_point(
	space_state: PhysicsDirectSpaceState3D,
	entry_point: Vector3,
	direction_normalized: Vector3,
	target_collider: CollisionObject3D,
) -> Vector3:
	var exclusion_list: Array[RID] = []
	var ray_origin_point := entry_point + direction_normalized * RAY_ORIGIN_OFFSET
	
	var query_exit := PhysicsRayQueryParameters3D.new()
	query_exit.hit_back_faces = true
	query_exit.exclude = exclusion_list
	
	while true:
		query_exit.from = ray_origin_point
		query_exit.to = ray_origin_point + direction_normalized * (RAY_LENGTH - RAY_ORIGIN_OFFSET)
		
		var intersect_result := space_state.intersect_ray(query_exit)
		if intersect_result.is_empty():
			push_error("COLLISION EXIT NOT FOUND")
			return entry_point
		
		var intersect_collider: CollisionObject3D = intersect_result.collider
		var intersect_position: Vector3 = intersect_result.position
		
		if intersect_collider == target_collider:
			return intersect_position
		else:
			exclusion_list.append(intersect_collider.get_rid())
			ray_origin_point = intersect_position + direction_normalized * RAY_ORIGIN_OFFSET
			push_error("ARMOR COLLIDERS OVERLAP: %s vs. %s" % [intersect_collider.name, target_collider.name])
	
	return entry_point
