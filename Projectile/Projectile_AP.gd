extends CharacterBody3D

@export var MUZZLE_VELOCITY: float= 1000.0;
@export var MASS: float = 6.79;
@export var DRAG_FACTOR: float = 0.005; # Note: DRAG_FACTOR replaces the complex (1/2 * rho * A * C_d) physics term

@export var MIN_RICOCHET_RAD: float = 1.2217 # 75deg
@export var MAX_RICOCHET_RAD: float = 0.7854 # 45deg

var initial_direction: Vector3 = Vector3.ZERO 

# TODO: move these into classes later on, no need for unnecessary nodes
@onready var collider_probe: Node3D = $ColliderProbe
@onready var ricochet_calculator: Node3D = $RicochetCalculator

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
		#push_warning("Current projectile velocity %s" % velocity)
		 
		look_at(global_position + velocity, Vector3.UP)
	
	# Calculate and handle motion vecotr
	var motion: Vector3 = velocity * delta
	var collision: KinematicCollision3D = move_and_collide(motion)
	
	if collision:
		_handle_collision(collision);


func _handle_collision(collision_info: KinematicCollision3D) -> void:
	var impact_velocity_norm: Vector3 = velocity.normalized()
	var surface_normal: Vector3 = collision_info.get_normal()
	push_error("normalized velocity vector: %s" % impact_velocity_norm)
	push_error("surface normal vector: %s" % surface_normal)
	
	var impact_angle_radians = _measure_collision_radian(impact_velocity_norm, surface_normal)
	
	push_warning("IMPACT ANGLE: %s" % impact_angle_radians)
	if impact_angle_radians > MIN_RICOCHET_RAD:
		push_warning("SHELL RICOCHETS")
		ricochet_calculator.get_reflection_velocity(velocity, surface_normal)
	elif impact_angle_radians >= MAX_RICOCHET_RAD and impact_angle_radians < MIN_RICOCHET_RAD:
		push_warning("SHELL HAS A CHANCE TO RICOCHET")
	else:
		push_warning("SHELL HITS")
	
	collider_probe.probe_thickness(impact_velocity_norm)
	queue_free()


func _measure_collision_radian(impact_velocity: Vector3, surface_normal: Vector3) -> float:
	var cos_angle = abs(impact_velocity.dot(surface_normal))
	var impact_angle_radians = acos(cos_angle)
	
	return impact_angle_radians
