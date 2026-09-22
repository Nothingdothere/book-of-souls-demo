extends CanvasLayer

signal opened
signal closed

var unlocked := false
var active := false
var turning := false
var lina_known := false
var page := 0
var target_page := 0
var turn_elapsed := 0.0
var entries: Array = []
var turn_frames: Array[Texture2D] = []
var root_control: Control
var stage: Control
var contents: Control
var animation: TextureRect
var photo: TextureRect
var heading: Label
var classification: Label
var body: RichTextLabel
var page_number: Label
var previous: Button
var next: Button
var handwriting: Font

func _ready() -> void:
	layer = 30
	entries = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/soul_dossiers.json"))
	for i in range(6):
		turn_frames.append(load("res://assets/ui/book/frame_%02d.png" % i))
	if OS.has_feature("web"):
		handwriting = preload("res://assets/fonts/Caveat.ttf")
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Segoe Script", "Gabriola"])
		handwriting = system_font
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.018, 0.015, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(dim)
	stage = Control.new()
	stage.size = Vector2(1536, 1024)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(stage)
	_texture(stage, load("res://assets/ui/book/book.png"), Rect2(0, 0, 1536, 1024))
	contents = Control.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(contents)
	photo = _texture(contents, null, Rect2(255, 200, 380, 510))
	photo.rotation = -0.025
	heading = _label(contents, Rect2(250, 705, 390, 85), 51)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classification = _label(contents, Rect2(840, 190, 430, 125), 23)
	classification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body = RichTextLabel.new()
	body.position = Vector2(835, 330)
	body.size = Vector2(450, 450)
	body.add_theme_font_override("normal_font", handwriting)
	body.add_theme_font_size_override("normal_font_size", 29 if OS.has_feature("web") else 21)
	body.add_theme_color_override("default_color", Color("34271d"))
	body.add_theme_constant_override("line_separation", 0 if OS.has_feature("web") else -3)
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(body)
	page_number = _label(contents, Rect2(880, 784, 320, 40), 20)
	page_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	animation = _texture(stage, turn_frames[0], Rect2(0, -270, 1536, 1536))
	var page_turn_material := ShaderMaterial.new()
	page_turn_material.shader = preload("res://shaders/book_page_turn.gdshader")
	page_turn_material.set_shader_parameter("base_frame", turn_frames[0])
	animation.material = page_turn_material
	animation.hide()
	previous = _button("Назад", Rect2(285, 890, 225, 52), turn.bind(-1))
	next = _button("Дальше", Rect2(1020, 890, 225, 52), turn.bind(1))
	_button("Закрыть · J / Esc", Rect2(620, 939, 310, 48), close)
	var caption := _label(stage, Rect2(570, 886, 395, 38), 20)
	caption.text = "Книга душ · нажми на страницу"
	caption.add_theme_color_override("font_color", Color("d9c6a0"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_layout)
	_layout()
	root_control.hide()

func _texture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _label(parent: Node, rect: Rect2, font_size: int) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", handwriting)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("34271d"))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.flat = true
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_color_override("font_color", Color("e5d0a6"))
	node.pressed.connect(callback)
	stage.add_child(node)
	return node

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := minf(size.x / 1536, size.y / 1024)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - Vector2(1536, 1024) * factor) * 0.5

func page_count() -> int:
	return 4 if lina_known else 3

func open() -> void:
	if not unlocked or active:
		return
	active = true
	turning = false
	animation.hide()
	_show_page()
	root_control.show()
	opened.emit()

func close() -> void:
	if not active:
		return
	active = false
	turning = false
	animation.hide()
	root_control.hide()
	closed.emit()

func _show_page() -> void:
	var entry: Dictionary = entries[page]
	photo.texture = load("res://assets/ui/book/%s.png" % entry["id"])
	heading.text = entry["name"]
	classification.text = entry["type"]
	body.text = entry["text"]
	body.position.y = 315 if "\n" in entry["type"] else 265
	body.size.y = 770 - body.position.y
	page_number.text = "%d / %d" % [page + 1, page_count()]
	contents.show()
	previous.disabled = page == 0
	next.disabled = page == page_count() - 1

func turn(direction: int) -> void:
	if not active or turning or page + direction < 0 or page + direction >= page_count():
		return
	target_page = page + direction
	turn_elapsed = 0.0
	turning = true
	contents.hide()
	previous.disabled = true
	next.disabled = true
	animation.texture = turn_frames[0 if direction > 0 else 5]
	animation.show()

func _process(delta: float) -> void:
	if not turning:
		return
	turn_elapsed += delta
	var frame := int(turn_elapsed * 10)
	if frame >= 6:
		turning = false
		page = target_page
		animation.hide()
		_show_page()
	else:
		animation.texture = turn_frames[frame if target_page > page else 5 - frame]

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_J, KEY_ESCAPE]:
			close()
		elif event.physical_keycode == KEY_RIGHT:
			turn(1)
		elif event.physical_keycode == KEY_LEFT:
			turn(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_turn_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_turn_from_screen_position(event.position)
		get_viewport().set_input_as_handled()

func _turn_from_screen_position(screen_position: Vector2) -> void:
	var point: Vector2 = stage.get_global_transform().affine_inverse() * screen_position
	if Rect2(140, 90, 1260, 750).has_point(point):
		turn(1 if point.x >= 768 else -1)
