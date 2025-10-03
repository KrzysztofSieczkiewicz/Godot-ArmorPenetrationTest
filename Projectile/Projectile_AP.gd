extends CharacterBody3D

@export var MUZZLE_VELOCITY: float= 1000.0;
@export var MASS: float = 6.79;
@export var DRAG_FACTOR: float = 0.005; # Note: DRAG_FACTOR replaces the complex (1/2 * rho * A * C_d) physics term

var initial_direction: Vector3 = Vector3.ZERO 

@onready var collider_probe: Node3D = $ColliderProbe

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
	var body_hit = collision_info.get_collider()
	
	var impact_point: Vector3 = collision_info.get_position()
	var impact_velocity: Vector3 = velocity.normalized()
	var surface_normal: Vector3 = collision_info.get_normal()
	
	var cos_angle = abs(impact_velocity.dot(surface_normal))
	var angle_between_velocity_and_normal = acos(cos_angle)
	var angle_deg = rad_to_deg(angle_between_velocity_and_normal)
	
	collider_probe.probe_thickness(impact_velocity.normalized())
	queue_free()
