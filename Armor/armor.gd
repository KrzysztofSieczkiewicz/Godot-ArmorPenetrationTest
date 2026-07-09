class_name ArmorComponent
extends StaticBody3D

"""
1. Detect collision when projectile enters the collider
2. Take collision point and vector, probe mesh along this vector (move a bit back so texture hit is guaranteed)
3. Take data from mesh (structural thickness) and proceed to calculate the ballistics

TODO: consider how to easily probe the real "angle" from mesh instead of collider - collision probing should occur only once
TODO: after changing mesh search from "collider surface normal on collision point" to mesh search add optimization layer using AABB to reduce mesh geometry searching
"""

@export_group("References")
@export var mesh_instance: MeshInstance3D
@export var data_texture: Texture2D											# TODO: this might be optional - texture must be unique per mesh, consider if they can be kept together - e.g. resource keeping mesh and texture together

@export_group("Settings")
@export var ray_offset_distance: float = 0.05 # meter
@export var max_ray_distance: float = 0.15 # meter

# Caches
var _cached_vertices: PackedVector3Array
var _cached_uvs: PackedVector2Array
var _texture_image: Image
var _texture_size: Vector2i


func _ready() -> void:
	if not mesh_instance:
		push_error("MeshInstance3D is missing on: ", name)
		return
	elif not mesh_instance.mesh:
		push_error("MeshInstance3D mesh is missing on: ", name)
		return
	if not data_texture:
		push_error("Data texture is missing on: ", name)
		return
	
	_texture_image = data_texture.get_image()
	if _texture_image:
		_texture_size = _texture_image.get_size()
	
	_cache_geometry()


### Extract the mesh geometry into RAM on ready
### This solution de-indexes vertices into bloated array, but it makes reading simple at the cost of RAM - plan for optimizations later
func _cache_geometry() -> void:
	var mesh: Mesh = mesh_instance.mesh
	var surface_count: int = mesh.get_surface_count()
	
	# Determine final flattened array size
	var deindexed_count: int = 0
	var surface_arrays: Array = []
	for surface in range(surface_count):
		var arrays: Array = mesh.surface_get_arrays(surface)
		surface_arrays.append(arrays)
		
		var raw_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var raw_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		
		if raw_indices.size() > 0:
			deindexed_count += raw_indices.size()
		else:
			deindexed_count += raw_vertices.size()
	
	# Allocate memory
	_cached_vertices = PackedVector3Array()
	_cached_uvs = PackedVector2Array()
	_cached_vertices.resize(deindexed_count)
	_cached_uvs.resize(deindexed_count)
	
	# Populate the arrays
	var write_index: int = 0
	for surface in range(surface_count):
		var arrays: Array = surface_arrays[surface]
		var raw_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var raw_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				
		if raw_indices.size() > 0:
			for i in range(raw_indices.size()):
				var idx: int = raw_indices[i]
				_cached_vertices[write_index] = raw_vertices[idx]
				_cached_uvs[write_index] = raw_uvs[idx]
				write_index += 1
		else:
			var count: int = raw_vertices.size()
			for i in range(count):
				_cached_vertices[write_index] = raw_vertices[i]
				_cached_uvs[write_index] = raw_uvs[i]
				write_index += 1


func evaluate_armor(global_hit_pos: Vector3, collided_surf_normal: Vector3) -> Dictionary:
	
	if _cached_vertices.size() == 0 or !_texture_image:			# Cache check
		push_error("No cached vertices or texture image")
		return {"thickness": 0.0, "material": 0.0, "valid": false}
		
	# Transform coordinates into local
	var inverse_transform = mesh_instance.global_transform.inverse()
	var local_intersection_point: Vector3 = inverse_transform * global_hit_pos
	
	# Determine ray start and dir
	var local_ray_dir: Vector3 = (inverse_transform.basis * -collided_surf_normal).normalized()
	var local_ray_start: Vector3 = local_intersection_point - (local_ray_dir * ray_offset_distance)
	
	# Determine first intersection point with the mesh
	var closest_dist: float = INF
	var closest_uv: Vector2 = Vector2.ZERO
	var hit_found: bool = false
	
	var face_count: int = _cached_vertices.size()
	
	for i in range(0, face_count, 3):
		var v0: Vector3 = _cached_vertices[i]
		var v1: Vector3 = _cached_vertices[i+1]
		var v2: Vector3 = _cached_vertices[i+2]
		
		var intersect_point = Geometry3D.ray_intersects_triangle(local_ray_start, local_ray_dir, v0, v1, v2)
		
		if intersect_point != null:
			var dist: float = local_ray_start.distance_to(intersect_point)
			
			push_warning("dist: ", dist)
			
			if dist < closest_dist and dist <= max_ray_distance:
				closest_dist = dist
				hit_found = true
				
				push_warning("hit found: ", hit_found)
				push_warning("closest dist: ", closest_dist)
				
				var bary_coord: Vector3 = _calculate_barycentric(intersect_point, v0, v1, v2)
				
				var uv0: Vector2 = _cached_uvs[i]
				var uv1: Vector2 = _cached_uvs[i+1]
				var uv2: Vector2 = _cached_uvs[i+2]
				closest_uv = (uv0 * bary_coord.x) + (uv1 * bary_coord.y) + (uv2 * bary_coord.z)
	
	if hit_found == false:
		push_error("No mesh intersection was found")
		return {"thickness": 0.0, "material": 0.0, "valid": false}
	
	var pixel_x: int = clampi(int(closest_uv.x * _texture_size.x), 0, _texture_size.x - 1)
	var pixel_y: int = clampi(int((1.0 - closest_uv.y) * _texture_size.y), 0, _texture_size.y - 1) # flipped on purpose
	var pixel_color: Color = _texture_image.get_pixel(pixel_x, pixel_y)
	
	return {																								# TODO: rethink the proper return
		"thickness": pixel_color.r, # Nominally mapped to 0.0 - 1.0 (multiply by max thickness config if needed)
		"material": pixel_color.g,  # Float representation of material ID/type index
		"valid": true
	}


# TODO: read and review - might be an overkill
## Computes the barycentric coordinates for point p with respect to triangle (a, b, c)
func _calculate_barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	
	var denom := d00 * d11 - d01 * d01
	
	# Safety check against zero-area triangles (degenerate geometry)
	if is_zero_approx(denom):
		return Vector3(1.0, 0.0, 0.0) # Fallback to vertex A
		
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	var u := 1.0 - v - w
	
	return Vector3(u, v, w)
