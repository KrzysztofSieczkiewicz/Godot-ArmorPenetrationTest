class_name ShellAP
extends Node3D

@export var muzzle_velocity: float = 1200.0 # m/s
@export var mass: float = 15.0 # kg
@export var shell_radius: float = 0.05 # m

var current_velocity: Vector3
var space_state: PhysicsDirectSpaceState3D
var sweep_shape: SphereShape3D

# Collision Layers ### TODO: read about these to ensure that this is really necessary
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
		_run_resolution_mode(start_pos, travel_vector, delta, hit_detected)
		pass



func _run_ghost_mode(start: Vector3, motion: Vector3) -> Dictionary:										# TODO: this will require some cleanup
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
		
		var rest_info = space_state.get_rest_info(query)
		
		if not rest_info.is_empty():
			var collider_id = rest_info.get("collider_id")
			var struck_object = instance_from_id(collider_id)
			print("Real Node Name: ", struck_object.name if struck_object else "Unknown Object")
			
			print("↳ [COLLISION DATA SUCCESS]")
			print("   - Struck Object : ", rest_info.get("collider"), " (ID: ", rest_info.get("collider_id"), ")")
			print("   - Exact Point   : ", rest_info.get("point"))
			print("   - Surface Normal: ", rest_info.get("normal"))
			print("   - Face Linear V : ", rest_info.get("linear_velocity"))
		
		return rest_info
		
	return {}


func _run_resolution_mode(start: Vector3, motion: Vector3, frame_delta: float, hit_data: Dictionary) -> void:
	var packet = ResolutionPacket.new()
	packet.impact_point = hit_data.get("point", global_position)
	packet.impact_normal = hit_data.get("normal", Vector3.UP)
	packet.projectile_velocity = current_velocity
	packet.target_collider = hit_data.get("collider")
	
	# Dynamic object or projectile relative velocity
	if packet.target_collider and packet.target_collider.has_method("get_velocity"):
		packet.target_velocity = packet.target_collider.get_velocity()
	else:
		packet.target_velocity = Vector3.ZERO
	
	packet.relative_velocity = packet.projectile_velocity - packet.target_velocity
	
	var distance_to_impact = start.distance_to(packet.impact_point)
	var time_to_impact = distance_to_impact / current_velocity.length()
	var remaining_delta = frame_delta - time_to_impact
	
	_process_balistic_resolver(packet, remaining_delta)


func _process_balistic_resolver(packet: ResolutionPacket, remaining_delta: float) -> void:
	var impact_dir = packet.relative_velocity.normalized()
	var cos_angle = impact_dir.dot(-packet.impact_normal)
	var impact_angle = acos(clamp(cos_angle, -1.0, 1.0))
	
	var normalization_factor = 0.05																	# TODO: make constant
	var effective_angle = max(0.0, impact_angle - normalization_factor)
	
	var ricochet_threshold = deg_to_rad(70.0)														# TODO: make constant
	
	if effective_angle > ricochet_threshold:
		_handle_ricochet(packet, effective_angle)
	else:
		_handle_penetration(packet, effective_angle)

func _handle_ricochet(packet: ResolutionPacket, angle: float):
	push_warning("Ricochet")
	pass
	
func _handle_penetration(packet: ResolutionPacket, angle: float):
	push_warning("Penetration")
	pass
