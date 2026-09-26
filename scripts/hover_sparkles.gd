extends Control

# Shared hover polish for the travel button and the soul-book icon: a few
# drifting embers, and — only where glow_enabled is turned on — a small
# soft glow. No shine sweep and no big ambient bloom; both looked wrong at
# UI scale and were cut per feedback.

@export var glow_enabled := false
@export var glow_radius := 18.0
@export var sparkle_amount := 10
@export var sparkle_velocity_min := 5.0
@export var sparkle_velocity_max := 14.0
@export var sparkle_scale_min := 0.5
@export var sparkle_scale_max := 1.1

var glow_alpha := 0.0
var sparkles: CPUParticles2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	sparkles = CPUParticles2D.new()
	sparkles.emitting = false
	sparkles.amount = sparkle_amount
	sparkles.lifetime = 1.4
	sparkles.preprocess = 0.3
	sparkles.texture = _spark_texture()
	sparkles.direction = Vector2.UP
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = sparkle_velocity_min
	sparkles.initial_velocity_max = sparkle_velocity_max
	sparkles.scale_amount_min = sparkle_scale_min
	sparkles.scale_amount_max = sparkle_scale_max
	sparkles.color = Color(1.0, 0.86, 0.55, 0.9)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	add_child(sparkles)

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
	sparkles.emitting = hovering
	if glow_enabled:
		var tween := create_tween()
		tween.tween_property(self, "glow_alpha", 1.0 if hovering else 0.0, 0.25)

func _process(_delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	sparkles.position = size * 0.5
	sparkles.emission_rect_extents = size * 0.5
	if glow_enabled:
		queue_redraw()

func _draw() -> void:
	if not glow_enabled or glow_alpha <= 0.0:
		return
	var glow := Color(1.0, 0.84, 0.5, 0.35 * glow_alpha)
	var center := size * 0.5
	for ring in range(4, 0, -1):
		var soft := glow
		soft.a *= 0.22
		draw_circle(center, glow_radius * float(ring) / 4.0, soft)
