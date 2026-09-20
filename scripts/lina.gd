extends Node2D

var resolved := false
var artwork: AnimatedSprite2D
var prompt: Label
var collision: CollisionShape2D
var departure_time := -1.0
var dark_mist := false

func _process(delta: float) -> void:
	if departure_time >= 0.0 and departure_time < 3.0:
		departure_time += delta
		queue_redraw()

func _draw() -> void:
	if departure_time < 0.0 or departure_time >= 3.0:
		return
	var opacity := sin(PI * departure_time / 3.0) * 0.45
	for i in range(36):
		var phase := float(i) * 2.39996
		var point := Vector2(sin(phase + departure_time) * (26 + i % 5 * 9), -40 - i * 7 - departure_time * 30)
		var tint := Color(0.045, 0.025, 0.065, opacity) if dark_mist else Color(0.35, 0.48, 0.92, opacity * 0.3)
		for ring in range(8, 0, -1):
			var soft_tint := tint
			soft_tint.a *= 0.16
			draw_circle(point, (12 + i % 6) * float(ring) / 8.0, soft_tint)
		if not dark_mist:
			draw_circle(point, 1.0, Color(0.9, 0.93, 1, opacity))

func _ready() -> void:
	artwork = AnimatedSprite2D.new()
	artwork.sprite_frames = preload("res://assets/npc/lina/lina_frames.tres")
	artwork.scale = Vector2.ONE * 0.23
	artwork.position = Vector2(0, (768 - 1480) * 0.23)
	add_child(artwork)
	artwork.play("idle")
	var solid := StaticBody2D.new()
	add_child(solid)
	collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(105, 300)
	collision.shape = shape
	collision.position.y = -150
	solid.add_child(collision)
	prompt = Label.new()
	prompt.text = "E — поговорить с девушкой"
	prompt.position = Vector2(-135, -375)
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color("eadbb6"))
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt)
	prompt.hide()

func depart(outcome: String) -> void:
	if resolved:
		return
	resolved = true
	departure_time = 0.0
	dark_mist = outcome == "oblivion"
	prompt.hide()
	collision.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(artwork, "modulate", Color(0.1, 0.08, 0.15, 0) if outcome == "oblivion" else Color(0.7, 0.85, 1, 0), 1.8)
	tween.tween_property(artwork, "position:y", artwork.position.y - 28, 1.8)
