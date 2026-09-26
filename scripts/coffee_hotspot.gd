extends Area2D

signal activated

@export var radius: float = 55.0

var hovering := false
var marker_enabled := false
var inspected := false
var glow_time := 0.0

func set_inspected(value: bool) -> void:
	inspected = value
	queue_redraw()

func set_enabled(value: bool) -> void:
	input_pickable = value
	marker_enabled = value
	if not value and hovering:
		hovering = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if marker_enabled and is_visible_in_tree():
		glow_time += delta
		queue_redraw()

func _ready() -> void:
	input_pickable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _on_mouse_entered() -> void:
	if not marker_enabled:
		return
	hovering = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	queue_redraw()

func _on_mouse_exited() -> void:
	hovering = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not input_pickable:
		return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		activated.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not marker_enabled:
		return
	# A tiny warm flame guides discovery before hovering. Its size stays
	# independent of the much larger, touch-friendly interaction radius.
	var pulse := 0.75 + 0.25 * sin(glow_time * 2.4 + position.x * 0.01)
	if inspected:
		pulse *= 0.25
	var flame := Vector2(0, -1.5 * sin(glow_time * 1.6))
	for ring in range(5, 0, -1):
		draw_circle(flame, float(ring) * 1.8, Color(1.0, 0.68, 0.22, 0.04 * pulse))
	draw_circle(flame + Vector2(0, -1), 2.0, Color(1.0, 0.84, 0.48, 0.75 * pulse))
	draw_circle(flame, 1.0, Color(1.0, 0.96, 0.75, pulse))
	if not hovering:
		return
	# Soft layered glow (same additive-rings trick as the smoke/mist effects)
	# rather than an outline, since these points sit on a single baked-in
	# background image with no separate cutout to highlight.
	var glow := Color(1.0, 0.85, 0.55, 0.5)
	for ring in range(6, 0, -1):
		var soft := glow
		soft.a *= 0.18
		draw_circle(Vector2.ZERO, radius * float(ring) / 6.0, soft)
