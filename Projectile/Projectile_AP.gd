extends CharacterBody3D

@export var SPEED: float= 50.0;

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D

var direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	# calculate movement vector:
	var velocity_vector: Vector3 = direction * SPEED;
	#TODO: finish with the move_and_collide
	
