extends RigidBody3D


@export var thickness_map: Texture2D
@export var max_thickness_mm: float = 100.0 # mm

var map_image																		# TODO: move to cache later (also consider using PackedByteArray for smaller size and faster access)

func _ready() -> void:
	if thickness_map:
		map_image = thickness_map.get_image()

func evaluate_armor(uv: Vector2) -> float:
	if not map_image:
		return 0.0
	
	var tex_width = map_image.get_width()
	var tex_height = map_image.get_height()
	
	var pixel_x = clamp(int(uv.x * tex_width), 0, tex_width - 1)
	var pixel_y = clamp(int(uv.y * tex_height), 0, tex_height - 1)
	
	var pixel_color = map_image.get_pixel(pixel_x, pixel_y)
	
	return pixel_color.r * max_thickness_mm
