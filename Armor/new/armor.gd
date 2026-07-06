class_name ArmorComponent
extends Node3D

"""
1. Detect collision when projectile enters the collider
2. Take collision point and vector, probe mesh along this vector (move a bit back so texture hit is guaranteed)
3. Take data from mesh (structural thickness) and proceed to calculate the ballistics

TODO: consider how to easily probe the real "angle" from mesh instead of collider - collision probing should 
TODO: this is highly inefficient if mesh gets big - consider Spatial Buckets, BVH or similar 
"""

@export_group("References")
@export var mesh_instance: MeshInstance3D
@export var data_texture: Texture2D											# TODO: this might be optional - texture must be unique per mesh, consider if they can be kept together - e.g. resource keeping mesh and texture together

@export_group("Settings")
@export var ray_offset_distance: float = 0.05 # meter
@export var max_ray_distance: float = 0.4

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
### This solution de-indexes vertices into bloated array, but it makes reading simple at the cost of RAM
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


func evaluate_armor(global_hit_pos: Vector3, global_ray_dir: Vector3) -> Dictionary:
	# Cache check
	if _cached_vertices.size() == 0 or !_texture_image:
		return {"thickness": 0.0, "material": 0.0, "valid": false}
		
	# Transform coordinates into local
	var inverse_transform = mesh_instance.global_transform.inverse()
	var local_intersection_point: Vector3 = inverse_transform * global_hit_pos

	# Determine first intersection point with the mesh
	var closest_dist: float = INF
	var closest_uv: Vector2 = Vector2.ZERO
	var triangle_found: bool = false
	
	var face_count: int = _cached_vertices.size()
	
	for i in range(0, face_count, 3):
		var v0: Vector3 = _cached_vertices[i]
		var v1: Vector3 = _cached_vertices[i+1]
		var v2: Vector3 = _cached_vertices[i+2]
		
		var closest_point: Vector3 = _get_closest_point_on_triangle(local_intersection_point, v0, v1, v2)
		var dist: float = local_intersection_point.distance_to(closest_point)
		
		if dist < closest_dist and dist <= max_ray_distance:
			closest_dist = dist
			triangle_found = true
			
			var bary_coord: Vector3 = _calculate_barycentric(closest_point, v0, v1, v2)
			
			var uv0: Vector2 = _cached_uvs[i]
			var uv1: Vector2 = _cached_uvs[i+1]
			var uv2: Vector2 = _cached_uvs[i+2]
			closest_uv = (uv0 * bary_coord.x) + (uv1 * bary_coord.y) + (uv2 * bary_coord.z)
	
	if triangle_found == false:
		push_error("No mesh intersection was found")
		return {"thickness": 0.0, "material": 0.0, "valid": false}
	
	var pixel_x: int = clampi(int(closest_uv.x * _texture_size.x), 0, _texture_size.x - 1)
	var pixel_y: int = clampi(int(closest_uv.y * _texture_size.y), 0, _texture_size.y - 1)					# TODO: if causes problems - consider y-flip
	var pixel_color: Color = _texture_image.get_pixel(pixel_x, pixel_y)
	
	return {																								# TODO: rethink the proper return
		"thickness": pixel_color.r, # Mapped to 0.0 - 1.0 (multiply by max thickness)
		"material": pixel_color.g,  # Representation of material ID/type index 								# TODO: simplify later
		"valid": true
	}


# TODO: read and review
## Finds the closest point on triangle (a, b, c) to point p
func _get_closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	
	# Check if P in vertex region outside A
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
		
	# Check if P in vertex region outside B
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
		
	# Check if P in edge region of AB, if so return projection of P onto AB
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1 / (d1 - d3)
		return a + v * ab
		
	# Check if P in vertex region outside C
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
		
	# Check if P in edge region of AC, if so return projection of P onto AC
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return a + w * ac
		
	# Check if P in edge region of BC, if so return projection of P onto BC
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + w * (c - b)
		
	# P is inside face region. Compute Q through barycentric coordinates
	var denom := 1.0 / (va + vb + vc)
	var v := vb * denom
	var w := vc * denom
	return a + ab * v + ac * w

# TODO: read and review
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
