extends RefCounted

# Reuse a small pool of sprites; mirrored neighbors share identical edge pixels.
# Keep the artist's original position, scale, texture, and draw order.
var source: Sprite2D
var origin: Vector2
var tile_width: float
var left_edge: float
var parallax: float
var initial_flip: bool
var sprites: Array[Sprite2D] = []
var first_tile := 0

func _init(art: Sprite2D, parallax_factor := 0.0) -> void:
	source = art
	origin = source.position
	tile_width = source.get_rect().size.x * source.scale.x
	left_edge = origin.x + source.get_rect().position.x * source.scale.x
	parallax = parallax_factor
	initial_flip = source.flip_h
	sprites.append(source)

func update(camera_x: float, viewport_width: float) -> void:
	var shift := (camera_x - 836.0) * parallax
	var required := maxi(5, ceili(viewport_width / tile_width) + 3)
	while sprites.size() < required:
		var copy := source.duplicate() as Sprite2D
		copy.name = str(source.name) + "Repeat" + str(sprites.size())
		source.get_parent().add_child(copy)
		source.get_parent().move_child(copy, source.get_index() + sprites.size())
		sprites.append(copy)
	first_tile = maxi(0, floori((camera_x - viewport_width * 0.5 - shift - left_edge) / tile_width) - 1)
	for i in range(sprites.size()):
		var tile := first_tile + i
		sprites[i].position = origin + Vector2(tile * tile_width + shift, 0.0)
		sprites[i].flip_h = initial_flip != (tile % 2 == 1)
