extends Node2D

@export_range(0.5, 1.0, 0.01) var gameplay_zoom := 0.75
@onready var original_interior: Texture2D = $CounterAndShelves.texture

func set_repaired(value: bool) -> void:
	$CounterAndShelves.texture = preload("res://assets/coffee/cafe_repaired.png") if value else original_interior
	$HotspotWall.visible = not value


func _ready() -> void:
	# F6 runs this location by itself. Give that preview the same framing as
	# the main game; the real player replaces DarkPreview in normal gameplay.
	if get_parent() is Window:
		var preview_camera := Camera2D.new()
		preview_camera.position = Vector2(836, 451)
		preview_camera.zoom = Vector2.ONE * gameplay_zoom
		add_child(preview_camera)
		preview_camera.make_current()
	else:
		$CoffeeSpawn/DarkPreview.hide()
