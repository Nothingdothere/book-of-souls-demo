extends CanvasLayer

var library: Node2D

func _ready() -> void:
	layer = 100
	library = get_parent()
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.06, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color("c6a875")
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Dev: F1 — скрыть/показать"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("b8ac98"))
	box.add_child(title)
	_button(box, "Зал распределения", func(): library._set_location("hall", library.hall_position))
	_button(box, "Кофейня «Точка»", func(): library._set_location("cafe", library.coffee_interior.get_node("CoffeeSpawn").position))
	_button(box, "Улица", func(): library._set_location("street", library.coffee_street.get_node("PlayerSpawn").position))

func _button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	box.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()
