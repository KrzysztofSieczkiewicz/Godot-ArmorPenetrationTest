extends Node

@onready var PROJECTILE_SPAWNER: Node3D = $ProjectileSpawner
@onready var BARREL: Node3D = $ProjectileSpawner

#var bullet = load("res://Projectile/Projectile_AP.tscn")
var bullet = load("res://Projectile/AP/ap_shell.tscn")

func _physics_process(delta: float) -> void:
	#if Input.is_action_just_pressed("Shoot"):
	#	var instance = bullet.instantiate()
	#	instance.position = PROJECTILE_SPAWNER.global_position
	#	var forward_vector: Vector3 = -PROJECTILE_SPAWNER.global_transform.basis.z
	#	instance.initial_direction = forward_vector
	#	get_parent().add_child(instance)
	if Input.is_action_just_pressed("Shoot"):
		# 1. Create the shell instance in memory
		var instance = bullet.instantiate() as ShellAP
		
		# 2. Spawn it into the world tree so it can register global coordinates
		get_parent().add_child(instance)
		
		# 3. Align it perfectly with the muzzle position and rotation
		instance.global_transform = PROJECTILE_SPAWNER.global_transform
		
		# 4. Trigger the custom initialization loop now that transforms are safe
		instance.launch()
