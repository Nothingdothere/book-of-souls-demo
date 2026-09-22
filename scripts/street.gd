extends Node2D

@export_range(0.5, 1.0, 0.01) var gameplay_zoom := 0.65

# The first stretch is arranged by hand in street.tscn. Only its left edge
# grows procedurally, so edits to the authored houses remain untouched.
const GAPS := [-24.0, 0.0, 0.0, 24.0, 120.0, 260.0, 390.0]
# How much slower the sky drifts than the ground, so it reads as a distant
# parallax layer (same idea as the hall's RepeatingArt, but that class only
# tiles rightward from its origin — the street needs infinite tiling to the
# left instead, so the sky gets its own small bidirectional tiler below).
# DistantHouses (street_far_buildings.png) is the actual skyline-with-clouds
# painting despite the name; DistantAlley (street_parallax.png, despite ITS
# name) is a separate alleyway backdrop, not the sky.
const SKY_PARALLAX := 0.55
# The pavement art is a rendered 3D slab that tapers down at both ends
# (not a straight-cut tile), so abutting copies edge-to-edge left a V-shaped
# notch where two tapered ends met. Overlapping by this many source pixels
# lets the next copy's flat middle cover the taper instead — the taper
# itself only runs about 90px deep before the top edge goes flat.
const PAVEMENT_OVERLAP := 200.0

@onready var house_sources: Array[Sprite2D] = [$LeftHouses, $RightHouses]
@onready var repeating_sources: Array[Sprite2D] = [
	$DistantAlley, $Pavement, $NearSilhouettes
]
@onready var sky_source: Sprite2D = $DistantHouses

var house_edge: float
var layer_edges: Array[float] = []
var backdrop_edge := 0.0
var rng := RandomNumberGenerator.new()

var sky_sprites: Array[Sprite2D] = []
var sky_tile_width: float
var sky_origin_x: float


func _ready() -> void:
	if get_parent() is Window:
		var preview_camera := Camera2D.new()
		preview_camera.position = Vector2($PlayerSpawn.position.x, 451)
		preview_camera.zoom = Vector2.ONE * gameplay_zoom
		add_child(preview_camera)
		preview_camera.make_current()
	else:
		$PlayerSpawn/DarkPreview.hide()
	rng.randomize()
	house_edge = minf(house_sources[0].position.x, house_sources[1].position.x)
	for source in repeating_sources:
		layer_edges.append(source.position.x)
	sky_origin_x = sky_source.position.x
	sky_tile_width = sky_source.get_rect().size.x * sky_source.scale.x
	sky_sprites.append(sky_source)
	ensure_visible(house_edge - 4000.0)


func ensure_visible(left_edge: float) -> void:
	var target := left_edge - 1700.0
	while house_edge > target:
		var source: Sprite2D = house_sources[rng.randi_range(0, house_sources.size() - 1)]
		var width := source.texture.get_width() * source.scale.x
		var gap: float = GAPS[rng.randi_range(0, GAPS.size() - 1)]
		var copy := _copy_sprite(source, house_edge - gap - width)
		copy.flip_h = rng.randf() < 0.5
		house_edge = copy.position.x

	for i in repeating_sources.size():
		var source: Sprite2D = repeating_sources[i]
		var width := source.texture.get_width() * source.scale.x
		var advance := width - PAVEMENT_OVERLAP * source.scale.x if source == $Pavement else width
		while layer_edges[i] > target:
			layer_edges[i] -= advance
			# Not mirrored: these are specific painted scenes (one car, one
			# fence, one alley), not a generic tile — flipping alternate
			# copies made the fence/pavement lines meet in an obvious V.
			_copy_sprite(source, layer_edges[i])

	_update_sky(left_edge)

	if target < backdrop_edge:
		backdrop_edge = target - 2000.0
		$Backdrop.polygon = PackedVector2Array([
			Vector2(backdrop_edge, -200), Vector2(2700, -200),
			Vector2(2700, 1100), Vector2(backdrop_edge, 1100)
		])


func _update_sky(left_edge: float) -> void:
	var view_width := get_viewport().get_visible_rect().size.x / gameplay_zoom
	var camera_x := left_edge + view_width * 0.5
	var shift := camera_x * SKY_PARALLAX
	var required := maxi(5, ceili(view_width / sky_tile_width) + 3)
	while sky_sprites.size() < required:
		var copy := sky_source.duplicate() as Sprite2D
		copy.name = str(sky_source.name) + "Repeat" + str(sky_sprites.size())
		add_child(copy)
		sky_sprites.append(copy)
	# Unlike RepeatingArt's first_tile, this is never clamped to zero: the
	# sky has to keep tiling as the camera_x goes arbitrarily negative.
	var first_tile := floori((camera_x - view_width * 0.5 - shift - sky_origin_x) / sky_tile_width) - 1
	for i in sky_sprites.size():
		var tile := first_tile + i
		sky_sprites[i].position.x = sky_origin_x + tile * sky_tile_width + shift
		# Not mirrored either: one painted skyline, not a generic tile.


func _copy_sprite(source: Sprite2D, x: float) -> Sprite2D:
	var copy := Sprite2D.new()
	copy.texture = source.texture
	copy.centered = false
	copy.position = Vector2(x, source.position.y)
	copy.scale = source.scale
	copy.z_index = source.z_index
	add_child(copy)
	return copy
