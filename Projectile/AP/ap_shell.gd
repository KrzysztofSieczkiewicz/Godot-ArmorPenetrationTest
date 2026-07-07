class_name ShellAP
extends Node3D

"""
1st Phase - Movement:
	1. Cast sphere forward and detect collisions
	2. When no collisions, move shell to the new position
	3. When collision detected, get impact details and move to phase 2

2nd Phase - Collision
	1. If overmatches -> go into phase 3
	2. If ricochets -> calculate next collison or return to phase 1
		2a. Determine Slip Distance (consider if depth matters as well)
		2b. Determine Gyroscopic Precession -> this might need to be moved into penetration_info as well, but may be an overcomplication - reconsider
		2c. Determine projectile integrity (shell energy loss (consider setting shell to 'tumble') and potential spall)
	
3rd Phase - ballistics
	1. If penetrates
		1a. Determine normalization and denormalization
		1b. If normalization or denormalization angle too high - trigger shatter at appropriate stage
		1c. Determine remaining energy and projectile spall
		1d. Determine further collisions
		1e. Return the armor weakening
	2. If not - calculate missing energy for penetration (TBD) and return the armor weakening
"""

"""
Future:
change all calculations to return relevant values instead of determining the shell behaviour.
do the same for armor
create external manager class that will determine both armor and shell behaviour post hit
"""

@export var muzzle_velocity: float = 1200.0 		# m/s
@export var mass: float = 15.0 						# kg
@export var shell_radius: float = 0.05 				# m
@export var ogive_radius: float = 3*shell_radius 	# m

@export var ricochet_critical_zone_angle: float = 55.0
@export var ricochet_threshold_angle: float = 70.0
@export var normalization_factor: float = 0.05

@export var gyro_progr_angle_min: float = 1
@export var gyro_progr_angle_max: float = 7

@onready var ricochet_angle_threshold_rad: float = deg_to_rad(ricochet_threshold_angle)

var current_velocity: Vector3
var space_state: PhysicsDirectSpaceState3D
var sweep_shape: SphereShape3D

# Collision Layers 																					# TODO: read about these to ensure that this is really necessary
const MASK_STATIC = 1
const MASK_DYNAMIC = 2
const MASK_PROJECTILE = 3

class ResolutionPacket:
	var impact_normal: Vector3
	var impact_point: Vector3
	var projectile_velocity: Vector3
	var target_velocity: Vector3
	var target_collider: Object
	var relative_velocity: Vector3

func launch() -> void:
	current_velocity = -global_transform.basis.z * muzzle_velocity
	
	sweep_shape = SphereShape3D.new()
	sweep_shape.radius = shell_radius
	
	space_state = get_world_3d().direct_space_state
	var start_pos = global_position
	var travel_vector = current_velocity * 0.1
	var end_pos = start_pos + travel_vector

func _physics_process(delta: float) -> void:
	space_state = get_world_3d().direct_space_state
	
	current_velocity.y -= 9.81 * delta
	
	var start_pos = global_position
	var travel_vector = current_velocity * delta
	var end_pos = start_pos + travel_vector
	
	var hit_detected = _run_ghost_mode(start_pos, travel_vector)
	if hit_detected.is_empty():
		global_position = end_pos
	else:
		_run_collision_mode(start_pos, travel_vector, delta, hit_detected)
		pass



func _run_ghost_mode(start: Vector3, motion: Vector3) -> Dictionary:								# TODO: replace shape sweep with Ray Bundle -> only perform shape sweep if armor collision is detected
	print("\n=================== [PHASE 1: GHOST MODE] ===================")
	print("Shell Position : ", start)
	print("Travel Vector  : ", motion, " (Distance this frame: ", motion.length(), "m)")
	print("Checking Mask  : ", MASK_STATIC | MASK_DYNAMIC | MASK_PROJECTILE, " (Looking for Layers 1, 2, 3)")
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape
	query.transform = Transform3D(Basis(), start)
	query.motion = motion
	query.collision_mask = MASK_STATIC | MASK_DYNAMIC | MASK_PROJECTILE
	
	var motion_result = space_state.cast_motion(query)
	
	if motion_result.is_empty():
		return {}
		
	var safe_fraction = motion_result[0]
	var unsafe_fraction = motion_result[1]
	
	if safe_fraction == 1.0:
		return {}

	if safe_fraction < 1.0:
		query.transform.origin = start + (motion * unsafe_fraction)
		query.motion = Vector3.ZERO
		
		var collision_points = space_state.collide_shape(query, 1)
		
		if not collision_points.is_empty(): # collide_shape returns an array of vector pairs [point_on_surface, point_on_primitive]
			var local_impact_point = collision_points[0]
			
			var ray_start = local_impact_point + (motion.normalized() * -0.05)
			var ray_end = local_impact_point + (motion.normalized() * 0.05)
			var ray_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, query.collision_mask)
			
			var ray_result = space_state.intersect_ray(ray_query)
			if not ray_result.is_empty():
				print("↳ [COLLISION DATA SUCCESS]")
				print("   - Struck Object : ", ray_result.get("collider"))
				return ray_result
		
	return {}


func _run_collision_mode(start: Vector3, motion: Vector3, frame_delta: float, hit_data: Dictionary) -> void:
	var packet = ResolutionPacket.new()
	packet.impact_point = hit_data.get("position", global_position)
	packet.impact_normal = hit_data.get("normal", Vector3.UP)
	packet.projectile_velocity = current_velocity
	packet.target_collider = hit_data.get("collider")
	
	# Dynamic object or projectile relative velocity
	if packet.target_collider and packet.target_collider.has_method("get_velocity"):
		packet.target_velocity = packet.target_collider.get_velocity()
	else:
		packet.target_velocity = Vector3.ZERO
	
	packet.relative_velocity = packet.projectile_velocity - packet.target_velocity
	
	var collision_armor_uv = _get_collision_uv(packet.impact_point, packet.impact_normal)
	push_warning(packet.target_collider)
	
	push_warning("Impact point: ", packet.impact_point)
	push_warning("Impact normal: ", packet.impact_normal)
	
	var armor_texture_thickness = packet.target_collider.evaluate_armor(packet.impact_point, packet.impact_normal)
	push_warning(armor_texture_thickness)
	
	var armor_structural_thickness = packet.target_collider.get_armor_thickness(collision_armor_uv)					# TODO: this might be unsafe - find a clear way of ensuring that collider has "armor thickness" - note: this might be much easier after moving most of collision into management class instead
	
	var distance_to_impact = start.distance_to(packet.impact_point)
	var time_to_impact = distance_to_impact / current_velocity.length()
	var remaining_delta = frame_delta - time_to_impact
	
	# Assuming that we're hitting an armor and not e.g. brick wall 													# TODO: add a condition to skip calculations if non-armor is hit
	_process_balistic_resolver(packet, remaining_delta, armor_structural_thickness)


func _process_balistic_resolver(packet: ResolutionPacket, remaining_delta: float, armor_thickness: float) -> void:
	var impact_dir = packet.relative_velocity.normalized()
	var cos_angle = impact_dir.dot(-packet.impact_normal)
	var impact_angle = acos(clamp(cos_angle, -1.0, 1.0))
	
	var td_ratio = armor_thickness / (2 * shell_radius)
	var is_overmatch = td_ratio < 0.5 and impact_angle > deg_to_rad(45.0)
	
	if is_overmatch:
		_handle_overmatch(packet, impact_angle, armor_thickness, td_ratio)
	elif impact_angle > ricochet_angle_threshold_rad:
		_handle_ricochet(packet, impact_angle)
	else:
		_handle_penetration(packet, impact_angle)



func _handle_ricochet(packet: ResolutionPacket, angle: float):
	push_warning("Ricochet")
	
	global_position = packet.impact_point + (packet.impact_normal * shell_radius)
	var reflected_dir = current_velocity.bounce(packet.impact_normal)
	
	var dynamic_friction: float = 0.4
	var graze_factor: float = remap(deg_to_rad(angle), ricochet_angle_threshold_rad, PI/2, dynamic_friction, 0.85)
	
	current_velocity = reflected_dir * graze_factor
	
	if current_velocity.length_squared() > 0.001:
		look_at(global_position - current_velocity.normalized(), Vector3.UP)


func _calc_slip_distance(angle: float) -> float:
	var scaling_coeff = 0.9 																		# should fit somewhere between 0.5 and 1.2 # TODO: parametrize later
	var slip_distance = ogive_radius / tan(angle) * scaling_coeff
	return slip_distance


func _calc_gyroscopic_precession(angle: float) -> float:
	var angle_coeff = (ricochet_critical_zone_angle - angle) / (ricochet_threshold_angle - ricochet_critical_zone_angle)
	var capped_max_angle = gyro_progr_angle_max - gyro_progr_angle_min
	var precession_angle = gyro_progr_angle_min + (capped_max_angle * angle_coeff)
	
	return precession_angle


func _handle_overmatch(packet: ResolutionPacket, impact_angle: float, armor_thickness: float, td_ratio: float):
	var thickness_modifier = 1.0 - (td_ratio / 0.5)
	var exit_denormalization = deg_to_rad(8.0) * thickness_modifier
	
	var exit_angle = impact_angle + exit_denormalization
	exit_angle = min(exit_angle, PI / 2.0 - 0.05) 																		# TODO: check if needs capping
	var residual_velocity = packet.projectile_velocity * (1.0 - (0.15 * thickness_modifier)) 							# TODO: ensure that this won't deflect the shell back into the plate (also that it will be sufficiently low angle)


func _handle_penetration(packet: ResolutionPacket, impact_angle: float):
	push_warning("Penetration")
	
	var effective_angle = max(0.0, impact_angle - normalization_factor) # normalization
	
	var impact_vector_norm: Vector3 = Vector3.ZERO
	var armor_thickness = BallisticProber.probe_thickness(space_state, packet.impact_point, impact_vector_norm)
	
	push_warning("Probed thickness: ", armor_thickness)
	pass


func _get_collision_uv(impact_point: Vector3, impact_normal: Vector3) -> Vector2:
	var ray_start = impact_point + (impact_normal * 0.01)
	var ray_end = impact_point - (impact_normal * 0.03)
	
	var collision_masks = MASK_STATIC | MASK_DYNAMIC | MASK_PROJECTILE 											# TODO: move higher up or get by parameter
	var uv_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_masks)
	uv_query.collide_with_bodies = true
	uv_query.collide_with_areas = true  																		# TODO: might not be necessary
	
	var uv_result = space_state.intersect_ray(uv_query)
	if uv_result.size() == 0:
		push_error("No collision found for UV query.")
		return Vector2.ZERO
		
	if "uv" in uv_result:
		return uv_result["uv"] as Vector2
		
	push_error("Collision occurred, but no UV coordinates were returned. Check collision shape type.")
	return Vector2.ZERO
