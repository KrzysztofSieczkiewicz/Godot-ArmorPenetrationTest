class_name ArmorComponent
extends Node3D

"""
1. Detect collision when projectile enters the collider
2. Take collision point and vector, probe mesh along this vector (move a bit back so texture hit is guaranteed)
3. Take data from mesh (structural thickness) and proceed to calculate the ballistics

TODO: consider how to easily probe the real "angle" from mesh instead of collider - collision probing should 
"""

@export_group("References")
@export var mesh_instance: MeshInstance3D
@export var data_texture: Texture2D											# TODO: this might be optional - texture must be unique per mesh, consider if they can be kept together - e.g. resource keeping mesh and texture together

# Caches
var _cached_vertices: PackedVector3Array
var _cached_uvs: PackedVector2Array
var _texture_image: Image
var _texture_size: Vector2i


func _ready() -> void:
	if not mesh_instance:
		push_error("MeshInstance3D is missing")
	elif not mesh_instance.mesh:
		push_error("MeshInstance3D mesh is missing")
	if not data_texture:
		push_error("Data texture is missing")
	
	_texture_image = data_texture.get_image()
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


func evaluate_armor_hit(global_hit_pos: Vector3, global_ray_dir: Vector3) -> void: #Dictionary:
	pass
