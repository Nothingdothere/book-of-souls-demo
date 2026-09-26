extends Node2D

@export_range(0.5, 1.0, 0.01) var gameplay_zoom := 0.75
## 0 — обычный фон; 1 — фон следует за камерой. Двигается только дальний слой.
@export_range(0.0, 1.0, 0.01) var background_parallax_strength := 0.55

@onready var background: Sprite2D = $Background
const RepeatingArt := preload("res://scripts/repeating_art.gd")
var repeating_layers: Array = []

func _ready() -> void:
	# Mirrored neighbours meet at the same painted edge. The sprite pool
	# stays small as the wastes extend, preserving each edited layer's scale.
	var reference_x: float = background.position.x + background.get_rect().get_center().x * background.scale.x
	for sprite in [background, $Midground, $GroundArt, $Foreground]:
		var strength: float = background_parallax_strength if sprite == background else 0.0
		repeating_layers.append(RepeatingArt.new(sprite, strength, reference_x, true))
	if get_parent() is Window:
		var preview_camera := Camera2D.new()
		preview_camera.position = Vector2($PlayerSpawn.position.x, 451)
		preview_camera.zoom = Vector2.ONE * gameplay_zoom
		add_child(preview_camera)
		preview_camera.make_current()
	else:
		$PlayerSpawn/DarkPreview.hide()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	# Use the actual camera centre, including smoothing and level limits.
	var camera_x := to_local(camera.get_screen_center_position()).x
	var view_width := get_viewport_rect().size.x / camera.zoom.x / absf(global_scale.x)
	_update_art(camera_x, view_width)

func _update_art(camera_x: float, view_width: float) -> void:
	for art in repeating_layers:
		art.update(camera_x, view_width)
