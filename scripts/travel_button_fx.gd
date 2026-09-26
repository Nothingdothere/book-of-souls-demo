extends Control

# Hover polish for the travel button: a soft pulsing glow (same layered-rings
# trick as coffee_hotspot.gd's proximity glow), a light sweep across the
# artwork, and a few drifting embers — all generated at runtime, no extra
# assets needed.

var glow_alpha := 0.0
var shine_progress := -1.0
var sparkles: CPUParticles2D
var shine_mask: Control
var shine_sprite: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	shine_mask = Control.new()
	shine_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shine_mask.clip_contents = true
	add_child(shine_mask)

	shine_sprite = TextureRect.new()
	shine_sprite.texture = _shine_texture()
	shine_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	shine_sprite.material = CanvasItemMaterial.new()
	shine_sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shine_mask.add_child(shine_sprite)

	sparkles = CPUParticles2D.new()
	sparkles.emitting = false
	sparkles.amount = 10
	sparkles.lifetime = 1.4
	sparkles.preprocess = 0.3
	sparkles.texture = _spark_texture()
	sparkles.direction = Vector2.UP
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 5.0
	sparkles.initial_velocity_max = 14.0
	sparkles.scale_amount_min = 0.5
	sparkles.scale_amount_max = 1.1
	sparkles.color = Color(1.0, 0.86, 0.55, 0.9)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(sparkles)

func _shine_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.97, 0.85, 0))
	gradient.add_point(0.5, Color(1, 0.97, 0.85, 0.9))
	gradient.set_color(1, Color(1, 0.97, 0.85, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 64
	texture.height = 8
	return texture

func _spark_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 16
	texture.height = 16
	return texture

func set_hovering(hovering: bool) -> void:
	var glow_tween := create_tween()
	glow_tween.tween_property(self, "glow_alpha", 1.0 if hovering else 0.0, 0.25)
	sparkles.emitting = hovering
	if hovering:
		_play_shine()

func _play_shine() -> void:
	shine_progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "shine_progress", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): shine_progress = -1.0)

func _process(_delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	sparkles.position = size * 0.5
	sparkles.emission_rect_extents = size * 0.5

	var sweep_width: float = size.y * 2.2
	shine_sprite.size = Vector2(sweep_width, size.y * 1.4)
	shine_sprite.rotation = deg_to_rad(18.0)
	shine_sprite.pivot_offset = shine_sprite.size * 0.5
	if shine_progress >= 0.0:
		var x: float = lerp(-sweep_width * 0.5, size.x + sweep_width * 0.5, shine_progress)
		shine_sprite.position = Vector2(x - shine_sprite.size.x * 0.5, size.y * 0.5 - shine_sprite.size.y * 0.5)
		shine_sprite.visible = true
	else:
		shine_sprite.visible = false

	queue_redraw()

func _draw() -> void:
	if glow_alpha <= 0.0:
		return
	var glow := Color(1.0, 0.82, 0.45, 0.35 * glow_alpha)
	var center := size * 0.5
	var base_radius: float = size.y * 0.6
	for ring in range(6, 0, -1):
		var soft := glow
		soft.a *= 0.2
		draw_circle(center, base_radius + size.x * 0.06 * float(ring), soft)
