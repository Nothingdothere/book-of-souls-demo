extends Node2D

@export_range(0.5, 1.0, 0.01) var gameplay_zoom := 0.65

# The first stretch is arranged by hand in street.tscn. Only its left edge
# grows procedurally, so edits to the authored houses remain untouched.
const GAPS := [-24.0, 0.0, 0.0, 24.0, 120.0, 260.0, 390.0]

@onready var house_sources: Array[Sprite2D] = [$LeftHouses, $RightHouses]
@onready var repeating_sources: Array[Sprite2D] = [
	$DistantAlley, $DistantHouses, $Pavement, $NearSilhouettes
]

var house_edge: float
var layer_edges: Array[float] = []
var backdrop_edge := 0.0
var rng := RandomNumberGenerator.new()


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
		while layer_edges[i] > target:
			layer_edges[i] -= width
			_copy_sprite(source, layer_edges[i])

	if target < backdrop_edge:
		backdrop_edge = target - 2000.0
		$Backdrop.polygon = PackedVector2Array([
			Vector2(backdrop_edge, -200), Vector2(2700, -200),
			Vector2(2700, 1100), Vector2(backdrop_edge, 1100)
		])


func _copy_sprite(source: Sprite2D, x: float) -> Sprite2D:
	var copy := Sprite2D.new()
	copy.texture = source.texture
	copy.centered = false
	copy.position = Vector2(x, source.position.y)
	copy.scale = source.scale
	copy.z_index = source.z_index
	add_child(copy)
	return copy
