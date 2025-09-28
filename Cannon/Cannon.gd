extends Node

@onready var PROJECTILE_SPAWNER: Node3D = $ProjectileSpawner
@onready var BARREL: Node3D = $ProjectileSpawner

var bullet = load("res://Projectile/Projectile_AP.tscn")
var instance

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Shoot"):
		var instance = bullet.instantiate()
		instance.position = PROJECTILE_SPAWNER.global_position
		instance.transform.basis = PROJECTILE_SPAWNER.global_transform.basis
		get_parent().add_child(instance)
		
