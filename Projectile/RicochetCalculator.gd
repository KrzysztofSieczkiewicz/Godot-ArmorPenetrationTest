extends Node

# TODO: include armor property - harder armor should increase angle between surface normal and reflected velocity vector
func get_reflection_velocity(impact_velocity: Vector3, surface_normal: Vector3) -> Vector3:
	
	var dot_product: float = impact_velocity.dot(surface_normal)
	var surface_normal_length_sq: float = surface_normal.length_squared();
	
	var vector_projection: Vector3 = (dot_product / surface_normal_length_sq) * surface_normal
	
	var armor_hardness_coefficient: float = 1.0 # TODO: parametrize this
	if armor_hardness_coefficient < 0.5:
		push_error("Invalid coefficient - value below 0.5 results in ricoche inside the surface")
	elif armor_hardness_coefficient >= 0.5 and armor_hardness_coefficient < 1:
		push_warning("Projectile ricochets with angle larger than perfect - the armor is harder")
	elif armor_hardness_coefficient == 1:
		push_warning("Projectile ricochets with perfect reflection angle")
	elif armor_hardness_coefficient > 1 and armor_hardness_coefficient < 1.5:
		push_warning("Projectile ricochets with angle smaller than perfect - the armor is softer")
	elif armor_hardness_coefficient >= 1.5:
		push_error("Calculation starts to fold here - coefficient is too high") 
	
	var reflected_velocity_vector: Vector3 = impact_velocity - (2 * armor_hardness_coefficient * vector_projection)
	return reflected_velocity_vector
