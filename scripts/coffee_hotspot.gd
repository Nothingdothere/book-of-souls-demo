extends Area2D

signal activated

@export var radius: float = 55.0

var hovering := false

func set_enabled(value: bool) -> void:
	input_pickable = value
	if not value and hovering:
		hovering = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
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
	hovering = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	queue_redraw()

func _on_mouse_exited() -> void:
	hovering = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()

func _draw() -> void:
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
