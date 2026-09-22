extends Node2D

@onready var camera: Camera2D = $Player/Camera2D
@onready var distant_view: Sprite2D = $BackgroundArt/DistantView
@onready var foreground: Sprite2D = $ForegroundArt/Books
@onready var player: CharacterBody2D = $Player
@onready var kas: Node2D = $Kas
@onready var dialogue: CanvasLayer = $Dialogue
@onready var controls: Label = $Interface/Controls
const TALK_DISTANCE := 170.0
const RepeatingArt := preload("res://scripts/repeating_art.gd")
var repeating_layers: Array = []
var lina: Node2D
var room_title: CanvasLayer
var book: CanvasLayer
var quest_unlocked := false
var book_seen := false
var quest_label: Label
var book_hint: Label
var mobile_controls: CanvasLayer

func _ready() -> void:
	# The level may be adjusted in the editor, but the walkable floor must
	# continue under every repeated room tile.
	var floor_collision: CollisionShape2D = $Ground/CollisionShape2D
	if floor_collision.shape is RectangleShape2D:
		var floor_boundary := WorldBoundaryShape2D.new()
		floor_boundary.distance = 100.0
		floor_collision.shape = floor_boundary
	dialogue.conversation_started.connect(_conversation_started)
	dialogue.conversation_finished.connect(_conversation_finished)
	dialogue.topic_finished.connect(_topic_finished)
	book = CanvasLayer.new()
	book.name = "SoulBook"
	book.set_script(preload("res://scripts/soul_book.gd"))
	add_child(book)
	book.opened.connect(_book_opened)
	book.closed.connect(_book_closed)
	mobile_controls = CanvasLayer.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.set_script(preload("res://scripts/mobile_controls.gd"))
	add_child(mobile_controls)
	controls.text = "A / D, стрелки — идти     ·     E — поговорить"
	controls.visible = not mobile_controls.mobile_enabled
	quest_label = _hud_label(Vector2(26, 60), 18)
	quest_label.text = "Задание: поговорить с Касом"
	book_hint = _hud_label(Vector2(26, 92), 17)
	book_hint.hide()
	lina = Node2D.new()
	lina.name = "Lina"
	lina.set_script(preload("res://scripts/lina.gd"))
	lina.position = Vector2(3100, 756)
	add_child(lina)
	room_title = CanvasLayer.new()
	room_title.set_script(preload("res://scripts/room_title.gd"))
	add_child(room_title)
	dialogue.soul_departure_requested.connect(lina.depart)
	dialogue.star_awarded.connect(player.award_soul_star)
	var old_furniture: Sprite2D = $BackgroundArt/Furniture
	var tables := Sprite2D.new()
	tables.name = "ReadingTables"
	tables.texture = preload("res://assets/background/reading_tables.png")
	tables.centered = false
	tables.position = old_furniture.position + Vector2(0, 101 * old_furniture.scale.y)
	tables.scale = old_furniture.scale
	$BackgroundArt.add_child(tables)
	for sprite in [old_furniture, tables, foreground]:
		var blend := ShaderMaterial.new()
		blend.shader = preload("res://shaders/room_transition.gdshader")
		blend.set_shader_parameter("incoming", sprite == tables)
		sprite.material = blend
	repeating_layers = [
		RepeatingArt.new(distant_view, 0.65),
		RepeatingArt.new($BackgroundArt/Library),
		RepeatingArt.new($BackgroundArt/FloorArt),
		RepeatingArt.new($BackgroundArt/Furniture),
		RepeatingArt.new(foreground, -0.10)
	]
	repeating_layers.append(RepeatingArt.new(tables))
	_update_environment()

func _process(_delta: float) -> void:
	_update_environment()
	kas.prompt.visible = not dialogue.active and not book.active and absf(player.position.x - kas.position.x) <= TALK_DISTANCE
	lina.prompt.visible = quest_unlocked and not dialogue.active and not book.active and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE
	if player.position.x >= 2250 and not dialogue.active and not book.active:
		room_title.reveal()

func _update_environment() -> void:
	# Retain the left and vertical framing limits, but never hit a right wall.
	camera.limit_right = maxi(camera.limit_right, ceili(player.global_position.x + 10000.0))
	var view_width := get_viewport().get_visible_rect().size.x / camera.zoom.x
	for art in repeating_layers:
		art.update(camera.get_screen_center_position().x, view_width)

func try_talk() -> void:
	if book.active:
		return
	if not dialogue.active and absf(player.position.x - kas.position.x) <= TALK_DISTANCE:
		dialogue.start()
	elif quest_unlocked and not dialogue.active and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE:
		dialogue.start("lina")

func _conversation_started() -> void:
	quest_label.hide()
	book_hint.hide()
	if dialogue.conversation_id == "lina":
		book.lina_known = true
		quest_label.text = "Задание: выслушать Лину и решить её судьбу"
	player.controls_locked = true
	player.velocity.x = 0.0
	var target: Node2D = lina if dialogue.conversation_id == "lina" else kas
	player.artwork.flip_h = player.position.x > target.position.x
	player.artwork.play("idle")
	if target == kas:
		kas.set_conversing(true, player.global_position.x)
	controls.hide()
	mobile_controls.set_gameplay_visible(false)

func _conversation_finished() -> void:
	player.controls_locked = false
	kas.set_conversing(false)
	controls.visible = not mobile_controls.mobile_enabled
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	if dialogue.lina_resolved:
		quest_label.text = "Задание выполнено: судьба Лины решена"
	if quest_unlocked:
		book_hint.text = "J — книга душ" if book_seen else "Новая книга душ · Нажми J, чтобы открыть досье"
		book_hint.show()

func _hud_label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eadbb6"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y", 2)
	$Interface.add_child(label)
	return label

func _topic_finished(character: String, topic: String) -> void:
	if character == "kas" and topic == "topic_6" and not quest_unlocked:
		quest_unlocked = true
		dialogue.lina_available = true
		book.unlocked = true
		quest_label.text = "Задание: поговорить с расколотой душой"

func _book_opened() -> void:
	book_seen = true
	player.controls_locked = true
	player.velocity.x = 0
	player.artwork.play("idle")
	controls.hide()
	mobile_controls.set_gameplay_visible(false)
	quest_label.hide()
	book_hint.hide()

func _book_closed() -> void:
	player.controls_locked = false
	controls.visible = not mobile_controls.mobile_enabled
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	book_hint.text = "J — книга душ"
	book_hint.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		if not dialogue.active:
			if book.active:
				book.close()
			else:
				book.open()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not dialogue.active:
			try_talk()
			get_viewport().set_input_as_handled()
