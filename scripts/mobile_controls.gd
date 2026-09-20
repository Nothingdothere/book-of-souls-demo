extends CanvasLayer

var library: Node
var mobile_enabled := false
var gameplay_visible := true
var root_control: Control
var book_button: Button
var rotate_hint: ColorRect

func _ready() -> void:
	layer = 10
	library = get_parent()
	_build_interface()
	mobile_enabled = OS.has_feature("web") and DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _build_interface() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var left := _button("◀", Vector2(30, -142), Vector2(106, 106), false)
	var right := _button("▶", Vector2(150, -142), Vector2(106, 106), false)
	left.button_down.connect(Input.action_press.bind("ui_left"))
	left.button_up.connect(Input.action_release.bind("ui_left"))
	right.button_down.connect(Input.action_press.bind("ui_right"))
	right.button_up.connect(Input.action_release.bind("ui_right"))
	var talk := _button("E\nГОВОРИТЬ", Vector2(-150, -142), Vector2(120, 106), true)
	talk.pressed.connect(func(): library.try_talk())
	book_button = _button("J\nКНИГА", Vector2(-282, -142), Vector2(120, 106), true)
	book_button.pressed.connect(_toggle_book)
	rotate_hint = ColorRect.new()
	rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_hint.color = Color(0.02, 0.015, 0.025, 0.88)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(rotate_hint)
	var rotate_text := Label.new()
	rotate_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rotate_text.position = Vector2(-240, -60)
	rotate_text.size = Vector2(480, 120)
	rotate_text.text = "Поверните телефон\nгоризонтально"
	rotate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_text.add_theme_font_size_override("font_size", 31)
	rotate_text.add_theme_color_override("font_color", Color("eadbb6"))
	rotate_hint.add_child(rotate_text)

func _button(text: String, offset: Vector2, dimensions: Vector2, from_right: bool) -> Button:
	var button := Button.new()
	button.name = text.replace("\n", "_")
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("f4e5c3"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.027, 0.045, 0.64)
	normal.border_color = Color(0.78, 0.65, 0.43, 0.62)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(28)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.36, 0.27, 0.17, 0.82)
	pressed.border_color = Color("f0d39b")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", pressed)
	if from_right:
		button.set_anchor(SIDE_LEFT, 1.0)
		button.set_anchor(SIDE_RIGHT, 1.0)
	button.set_anchor(SIDE_TOP, 1.0)
	button.set_anchor(SIDE_BOTTOM, 1.0)
	button.position = offset
	root_control.add_child(button)
	return button

func _process(_delta: float) -> void:
	if not mobile_enabled:
		return
	book_button.disabled = not library.book.unlocked
	book_button.modulate.a = 1.0 if library.book.unlocked else 0.42

func set_mobile_enabled(value: bool) -> void:
	mobile_enabled = value
	if is_instance_valid(library) and is_instance_valid(library.controls):
		library.controls.visible = not value and not library.dialogue.active and not library.book.active
	_update_layout()

func set_gameplay_visible(value: bool) -> void:
	gameplay_visible = value
	if not value:
		Input.action_release("ui_left")
		Input.action_release("ui_right")
	_update_layout()

func _toggle_book() -> void:
	if not library.book.unlocked or library.dialogue.active:
		return
	if library.book.active:
		library.book.close()
	else:
		library.book.open()

func _update_layout() -> void:
	if not is_instance_valid(root_control):
		return
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	root_control.visible = mobile_enabled and gameplay_visible
	rotate_hint.visible = mobile_enabled and portrait
