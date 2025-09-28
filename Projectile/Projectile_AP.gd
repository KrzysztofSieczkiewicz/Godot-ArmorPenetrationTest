extends CharacterBody3D

@export var MUZZLE_VELOCITY: float= 100.0;
@export var MASS: float = 6.79;
@export var DRAG_FACTOR: float = 0.005; # Note: DRAG_FACTOR replaces the complex (1/2 * rho * A * C_d) physics term

var initial_direction: Vector3 = Vector3.ZERO 

@onready var thickness_raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	if initial_direction != Vector3.ZERO:
		velocity = initial_direction * MUZZLE_VELOCITY
		look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity += get_gravity() * delta 
	
	# Rotate the projectile to match the velocity vector
	if velocity.length_squared() > 0.01:
		var current_speed = velocity.length()
		var drag_force_magnitude = DRAG_FACTOR * (current_speed * current_speed)
		var drag_acceleration_magnitude = drag_force_magnitude / MASS
		var drag_deceleration = velocity.normalized() * drag_acceleration_magnitude
		velocity -= drag_deceleration * delta
		push_warning("Current projectile velocity %s" % velocity)
		 
		look_at(global_position + velocity, Vector3.UP)
	
	# Calculate and handle motion vecotr
	var motion: Vector3 = velocity * delta
	var collision: KinematicCollision3D = move_and_collide(motion)
	
	if collision:
		_handle_collision(collision);


func _handle_collision(collision_info: KinematicCollision3D) -> void:
	var body_hit = collision_info.get_collider()
	
	var impact_velocity: Vector3 = velocity.normalized()
	var surface_normal: Vector3 = collision_info.get_normal()
	
	var cos_angle = abs(impact_velocity.dot(surface_normal))
	var angle_between_velocity_and_normal = acos(cos_angle)
	var angle_deg = rad_to_deg(angle_between_velocity_and_normal)
	
	var angle_of_impact = 90.0 - angle_deg 
	
	_trigger_raycast_collision_check()
	#push_warning("Collision detected! Collision angle %s" % angle_of_impact)
	queue_free()

func _trigger_raycast_collision_check() -> float:
	var OFFSET_DISTANCE = 0.01
	var RAY_LENGTH = 500.0

	thickness_raycast.enabled = true
	thickness_raycast.target_position = initial_direction.normalized() * RAY_LENGTH 
	thickness_raycast.force_raycast_update()

	if not thickness_raycast.is_colliding():
		thickness_raycast.enabled = false
		push_warning("Ray did not hit the mesh.")
		return 0.0
	
	var entry_point: Vector3 = thickness_raycast.get_collision_point()
	var entry_normal: Vector3 = thickness_raycast.get_collision_normal()
	
	var inward_direction: Vector3 = -entry_normal.normalized()
	var ray_origin: Vector3 = entry_point + (inward_direction * OFFSET_DISTANCE)
	
	thickness_raycast.global_transform.origin = ray_origin
	var global_end_point = ray_origin + inward_direction * RAY_LENGTH
	thickness_raycast.target_position = thickness_raycast.to_local(global_end_point)
	thickness_raycast.force_raycast_update()
	
	if not thickness_raycast.is_colliding():
		thickness_raycast.enabled = false
		push_warning("Ray entered mesh but did not find an exit point within bounds.")
		return 0.0
	
	var exit_point: Vector3 = thickness_raycast.get_collision_point()
	var thickness: float = entry_point.distance_to(exit_point)
	
	thickness_raycast.enabled = false
	
	print("Mesh Entry Point: ", entry_point)
	print("Mesh Exit Point:  ", exit_point)
	print("Calculated Thickness: ", thickness)
	
	return thickness
