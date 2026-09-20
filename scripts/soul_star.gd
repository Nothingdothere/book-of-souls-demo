extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	position = Vector2(12 if get_parent().artwork.flip_h else -12, -355)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(elapsed * 2.0)
	draw_circle(Vector2.ZERO, 9, Color(0.7, 0.8, 1, 0.08 * pulse))
	draw_circle(Vector2.ZERO, 4, Color(1, 0.85, 0.5, 0.25 * pulse))
	draw_line(Vector2(-3, 0), Vector2(3, 0), Color(1, 0.92, 0.7, pulse), 1.0, true)
	draw_line(Vector2(0, -4), Vector2(0, 4), Color(1, 0.92, 0.7, pulse), 1.0, true)
