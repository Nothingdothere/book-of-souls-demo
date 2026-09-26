extends CanvasLayer

class SpeakerIcon extends Control:
	var muted := false

	func _draw() -> void:
		var ink := Color("e7c990")
		draw_rect(Rect2(9, 18, 6, 9), ink)
		draw_colored_polygon(PackedVector2Array([
			Vector2(15, 18), Vector2(23, 12), Vector2(23, 33), Vector2(15, 27)
		]), ink)
		if muted:
			draw_line(Vector2(29, 18), Vector2(36, 27), ink, 2.0, true)
			draw_line(Vector2(36, 18), Vector2(29, 27), ink, 2.0, true)
		else:
			draw_arc(Vector2(23, 22.5), 8, -0.85, 0.85, 16, ink, 2.0, true)
			draw_arc(Vector2(23, 22.5), 13, -0.85, 0.85, 20, ink, 2.0, true)

var button: Button
var icon: SpeakerIcon

func _ready() -> void:
	# Keep sound accessible above dialogue, the book and the welcome popup.
	layer = 110
	button = Button.new()
	button.name = "MuteButton"
	button.set_anchor(SIDE_LEFT, 1.0)
	button.set_anchor(SIDE_RIGHT, 1.0)
	button.offset_left = -66
	button.offset_right = -22
	button.offset_top = 84
	button.offset_bottom = 128
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggle_mode = true
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.04, 0.025, 0.88)
	normal.border_color = Color("a88d5f")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.11, 0.065, 0.94)
	hover.border_color = Color("f0d39b")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	add_child(button)
	icon = SpeakerIcon.new()
	icon.size = Vector2(44, 44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	button.set_pressed_no_signal(muted)
	_update_icon(muted)
	button.toggled.connect(_toggle_mute)

func _toggle_mute(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	_update_icon(muted)

func _update_icon(muted: bool) -> void:
	icon.muted = muted
	icon.queue_redraw()
	button.tooltip_text = "Включить звук" if muted else "Выключить звук"
