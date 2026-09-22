extends CanvasLayer

signal conversation_started
signal conversation_finished
signal line_shown(speaker: String)
signal soul_departure_requested(outcome: String)
signal star_awarded
signal topic_finished(character: String, topic: String)
signal followup_finished

const DATA_PATH := "res://dialogue/kas_intro.json"
const PANEL := preload("res://assets/ui/dialogue/dialogue_panel_darkness.png")
const DARK := preload("res://assets/ui/dialogue/portrait_dark.png")
const KAS := preload("res://assets/ui/dialogue/portrait_kas.png")
const LINA := preload("res://assets/ui/dialogue/portrait_lina.png")
const BLUR := preload("res://shaders/dialogue_blur.gdshader")
const LETTERS_PER_SECOND := 42.0
const PAGE_LENGTH := 220

var active := false
var choosing := false
var current_speaker := ""
var current_topic := ""
var visited: Dictionary = {}
var data: Dictionary = {}
var lines: Array = []
var line_index := 0
var pages: Array[String] = []
var page_index := 0
var revealed := 0.0
var root_control: Control
var stage: Control
var portrait: TextureRect
var speaker_label: Label
var body: RichTextLabel
var hint: Label
var choices: GridContainer
var skip_intro_button: Button
var conversation_id := "kas"
var histories: Dictionary = {}
var pending_outcome := ""
var lina_resolved := false
var lina_available := false
var departed := false
var awarded := false
var followup_completed := false

func _ready() -> void:
	layer = 20
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed
	_build_interface()
	get_viewport().size_changed.connect(_layout)
	_layout()
	root_control.hide()

func _make_texture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(node)
	return node

func _make_label(rect: Rect2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(node)
	return node

func _build_interface() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	# Capture/blur the world before drawing any dialogue art or text.
	var blur := ColorRect.new()
	blur.name = "WorldBlur"
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = BLUR
	blur.material = blur_material
	root_control.add_child(blur)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.018, 0.014, 0.024, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(dim)
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(stage)
	# Draw the portrait first: the frame naturally covers its lower edge.
	portrait = _make_texture(DARK, Rect2(94, 109, 380, 380))
	_make_texture(PANEL, Rect2(24, 300, 1232, 410.6667))
	speaker_label = _make_label(Rect2(169, 471, 940, 29), 21, Color("d9c5a0"))
	body = RichTextLabel.new()
	body.position = Vector2(169, 507)
	body.size = Vector2(940, 122)
	body.add_theme_font_size_override("normal_font_size", 21)
	body.add_theme_color_override("default_color", Color("eee6d8"))
	body.add_theme_constant_override("line_separation", 3)
	body.scroll_active = false
	body.bbcode_enabled = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(body)
	hint = _make_label(Rect2(169, 651, 940, 25), 14, Color("b8ac98"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	choices = GridContainer.new()
	choices.position = Vector2(169, 504)
	choices.size = Vector2(940, 132)
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 24)
	choices.add_theme_constant_override("v_separation", 5)
	stage.add_child(choices)
	skip_intro_button = Button.new()
	skip_intro_button.text = "К вопросам"
	skip_intro_button.position = Vector2(925, 471)
	skip_intro_button.size = Vector2(184, 29)
	skip_intro_button.flat = true
	skip_intro_button.focus_mode = Control.FOCUS_NONE
	skip_intro_button.add_theme_font_size_override("font_size", 16)
	skip_intro_button.add_theme_color_override("font_color", Color("d9c5a0"))
	skip_intro_button.add_theme_color_override("font_hover_color", Color("ffe2ac"))
	skip_intro_button.pressed.connect(skip_intro)
	stage.add_child(skip_intro_button)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = Vector2((viewport_size.x - 1280.0 * factor) * 0.5, viewport_size.y - 720.0 * factor)

func start(character := "kas") -> void:
	if active or (character == "lina" and (lina_resolved or not lina_available)):
		return
	if character == "kas_return" and (not lina_resolved or followup_completed):
		return
	histories[conversation_id] = visited
	conversation_id = character
	visited = histories.get(character, {})
	data = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/%s_intro.json" % character))
	pending_outcome = ""
	active = true
	choosing = false
	current_topic = ""
	lines = data["intro"]
	line_index = 0
	root_control.show()
	conversation_started.emit()
	_show_line()

func _paginate(text: String) -> Array[String]:
	var result: Array[String] = []
	var remainder := text
	while remainder.length() > PAGE_LENGTH:
		var cut := remainder.rfind(" ", PAGE_LENGTH)
		if cut < PAGE_LENGTH / 2:
			cut = PAGE_LENGTH
		result.append(remainder.substr(0, cut))
		remainder = remainder.substr(cut).strip_edges()
	result.append(remainder)
	return result

func _show_line() -> void:
	choosing = false
	skip_intro_button.visible = current_topic == "" and pending_outcome == ""
	choices.hide()
	body.show()
	var line: Dictionary = lines[line_index]
	current_speaker = line["speaker"]
	portrait.visible = current_speaker in ["dark", "kas", "lina"]
	portrait.texture = DARK if current_speaker == "dark" else LINA if current_speaker == "lina" else KAS
	var on_right := current_speaker == "dark" if conversation_id.begins_with("kas") else current_speaker == "lina"
	portrait.position.x = 806.0 if on_right else 94.0
	portrait.flip_h = conversation_id.begins_with("kas")
	speaker_label.text = {"dark": "ДАРК", "kas": "КАС", "lina": "ЛИНА"}.get(current_speaker, "")
	if line.get("effect", "") == "depart":
		_depart()
	if line.get("effect", "") == "star":
		_award()
	pages = _paginate(line["text"])
	page_index = 0
	_show_page()
	line_shown.emit(current_speaker)

func _show_page() -> void:
	body.text = pages[page_index]
	body.visible_characters = 0
	revealed = 0.0
	hint.text = "Клик — показать текст целиком   ·   Esc — закончить разговор"

func _process(delta: float) -> void:
	if active and not choosing and is_revealing():
		revealed += delta * LETTERS_PER_SECOND
		body.visible_characters = mini(int(revealed), body.text.length())
		if not is_revealing():
			hint.text = "Клик или пробел — дальше   ·   Esc — закончить разговор"

func is_revealing() -> bool:
	return body.visible_characters >= 0 and body.visible_characters < body.text.length()

func skip_intro() -> void:
	if not active or choosing or current_topic != "" or pending_outcome != "":
		return
	if conversation_id == "kas_return":
		_finish_followup()
		return
	_show_choices()

func advance() -> void:
	if not active or choosing:
		return
	if is_revealing():
		body.visible_characters = -1
		hint.text = "Клик или пробел — дальше   ·   Esc — закончить разговор"
	elif page_index + 1 < pages.size():
		page_index += 1
		_show_page()
	elif line_index + 1 < lines.size():
		line_index += 1
		_show_line()
	else:
		if pending_outcome != "":
			close()
			return
		if conversation_id == "kas_return":
			_finish_followup()
			return
		if current_topic != "":
			visited[current_topic] = true
			topic_finished.emit(conversation_id, current_topic)
		if data.get("topics", []).is_empty():
			close()
			return
		_show_choices()

func _finish_followup() -> void:
	if not followup_completed:
		followup_completed = true
		followup_finished.emit()
	close()

func _button(text: String, callback: Callable, already_read := false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(458, 28)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("b3ab9e") if already_read else Color("eee6d8"))
	button.add_theme_color_override("font_hover_color", Color("ffe2ac"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.105, 0.1, 0.3)
	normal.content_margin_left = 9
	normal.content_margin_right = 9
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.4, 0.32, 0.23, 0.48)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	choices.add_child(button)

func _clear_choices(title: String) -> void:
	choosing = true
	skip_intro_button.hide()
	current_speaker = ""
	portrait.hide()
	body.hide()
	speaker_label.text = title
	hint.text = "Выбери тему   ·   Esc — закончить разговор"
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _available_topics() -> Array:
	return data["topics"].filter(func(topic): return _requirements_met(topic.get("requires", [])))

func _requirements_met(requirements: Array) -> bool:
	for requirement in requirements:
		if not visited.has(requirement):
			return false
	return true

func _show_choices(menu_page := 0) -> void:
	_clear_choices("О чём спросить Лину?" if conversation_id == "lina" else "О чём спросить Каса?")
	var topics := _available_topics()
	var page_size := 5 if conversation_id == "lina" else 6
	var count := ceili(float(topics.size()) / page_size)
	menu_page = menu_page % maxi(1, count)
	for topic in topics.slice(menu_page * page_size, (menu_page + 1) * page_size):
		var topic_id: String = topic["id"]
		var read_before := visited.has(topic_id)
		_button(("(прочитано) " if read_before else "") + topic["label"], choose_topic.bind(topic_id), read_before)
	if conversation_id == "lina":
		_button("Вынести решение", _show_verdict)
	if count > 1:
		_button("Другие вопросы (%d/%d)" % [menu_page + 1, count], _show_choices.bind(menu_page + 1))
	_button("Закончить разговор", close)
	choices.show()
	choices.get_child(0).grab_focus()

func choose_topic(topic_id: String) -> void:
	if not active or not choosing:
		return
	for topic in _available_topics():
		if topic["id"] == topic_id:
			current_topic = topic_id
			lines = topic["lines"]
			line_index = 0
			_show_line()
			return

func _show_verdict() -> void:
	_clear_choices("Решение Дарка")
	_button("Отправить Лину на перерождение", choose_verdict.bind("rebirth"))
	_button("Отправить Лину в забвение", choose_verdict.bind("oblivion"))
	_button("Задать другие вопросы", _show_choices)
	choices.show()
	choices.get_child(0).grab_focus()

func choose_verdict(verdict: String) -> void:
	if not active or not choosing or conversation_id != "lina" or verdict not in ["rebirth", "oblivion"]:
		return
	pending_outcome = "oblivion" if verdict == "oblivion" else "rebirth_understood" if _requirements_met(data["understood_requires"]) else "rebirth_rushed"
	current_topic = ""
	lines = data["endings"][pending_outcome]
	line_index = 0
	_show_line()

func _depart() -> void:
	if not departed and pending_outcome != "":
		departed = true
		soul_departure_requested.emit(pending_outcome)

func _award() -> void:
	if not awarded and pending_outcome == "rebirth_understood":
		awarded = true
		star_awarded.emit()

func close() -> void:
	if not active:
		return
	if pending_outcome != "":
		_depart()
		_award()
		lina_resolved = true
	active = false
	choosing = false
	root_control.hide()
	conversation_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif not choosing and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			advance()
			get_viewport().set_input_as_handled()
	elif not choosing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()
	elif not choosing and event is InputEventScreenTouch and event.pressed:
		advance()
		get_viewport().set_input_as_handled()
