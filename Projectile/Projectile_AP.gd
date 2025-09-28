extends CharacterBody3D

@export var SPEED: float= 50.0;

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D

var initial_direction: Vector3 = Vector3.ZERO 

func _ready() -> void:
	if initial_direction != Vector3.ZERO:
		velocity = initial_direction * SPEED
		look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	# calculate movement vector:
	var motion: Vector3 = velocity * delta
	
	var collision: KinematicCollision3D = move_and_collide(motion)
	
	if collision:
		_handle_collision(collision);

func _handle_collision(collision_info: KinematicCollision3D) -> void:
	var body_hit = collision_info.get_collider()
	
	var collision_angle = collision_info.get_angle()
	
	push_warning("Collision detected! Collided body: %s" % body_hit)
	push_warning("Collision detected! Collision angle %s" % rad_to_deg(collision_angle))
	
