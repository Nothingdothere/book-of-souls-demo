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
var coffee_world: Node2D
var coffee_interior: Node2D
var coffee_street: Node2D
var default_player_art_scale := Vector2(0.285, 0.285)
var travel_button: Button
var location := "hall"
var hall_position := Vector2(687, 771)
var point_visited := false
var walk_quest_active := false
var diana_met := false
var diana: Node2D
var hotspots: Array = []
var transitioning := false
var intro_active := false
var quest_toast: Label
var quest_toast_shown := false
var hall_music: AudioStreamPlayer
var point_music: AudioStreamPlayer
var door_sfx: AudioStreamPlayer
var bell_sfx: AudioStreamPlayer

func _ready() -> void:
	default_player_art_scale = player.get_node("Artwork").scale
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
	dialogue.followup_finished.connect(_followup_finished)
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
	coffee_world = Node2D.new()
	coffee_world.name = "PointWorld"
	add_child(coffee_world)
	coffee_interior = preload("res://scenes/coffee.tscn").instantiate()
	coffee_street = preload("res://scenes/street.tscn").instantiate()
	coffee_world.add_child(coffee_interior)
	coffee_world.add_child(coffee_street)
	coffee_interior.get_node("CoffeeSpawn/DarkPreview").hide()
	coffee_world.hide()
	coffee_street.hide()
	diana = coffee_street.get_node("Diana")
	# Street content sits in the same world space as the hall (only hidden,
	# not offset), so her blocking collision must start disabled or it walls
	# off part of the hall floor before the player ever visits the street.
	diana.get_node("Body/CollisionShape2D").disabled = true
	_connect_hotspot("HotspotMachine", "coffee_hotspot_machine")
	_connect_hotspot("HotspotGarland", "coffee_hotspot_garland")
	_connect_hotspot("HotspotWall", "coffee_hotspot_wall")
	_connect_hotspot("HotspotCat", "coffee_hotspot_cat")
	_connect_hotspot("HotspotBackroom", "coffee_hotspot_backroom")
	_create_travel_button()
	_create_quest_toast()
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
	_setup_audio()
	_setup_intro_popup()
	if OS.is_debug_build():
		var dev_panel := CanvasLayer.new()
		dev_panel.set_script(preload("res://scripts/dev_panel.gd"))
		add_child(dev_panel)

func _setup_intro_popup() -> void:
	# Test scripts run this same scene via `--script tests/xyz.gd` rather
	# than a real boot; skip the blocking popup there or every movement/
	# interaction test would freeze at controls_locked with nothing to
	# click "Начать" for.
	if "--script" in OS.get_cmdline_args():
		return
	# Check before building anything: the popup's own _ready() (art, sound,
	# tweens) would otherwise run for an instant only to be torn down again.
	if FileAccess.file_exists("user://intro_seen.marker"):
		return
	_show_intro_popup()

func _show_intro_popup() -> void:
	var popup := CanvasLayer.new()
	popup.set_script(preload("res://scripts/intro_popup.gd"))
	intro_active = true
	player.controls_locked = true
	popup.dismissed.connect(func():
		intro_active = false
		player.controls_locked = false
	)
	add_child(popup)

func _setup_audio() -> void:
	hall_music = _looping_player("res://assets/audio/music/hall_theme.mp3", -33.0)
	point_music = _looping_player("res://assets/audio/music/point_theme.mp3", -29.0)
	door_sfx = _sfx_player("res://assets/audio/sfx/door_open.ogg", -20.0)
	bell_sfx = _sfx_player("res://assets/audio/sfx/shop_bell.wav", -20.0)
	hall_music.play()

func _looping_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.stream = load(path)
	player_node.volume_db = volume_db
	player_node.finished.connect(player_node.play)
	add_child(player_node)
	return player_node

func _sfx_player(path: String, volume_db := 0.0) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.stream = load(path)
	player_node.volume_db = volume_db
	add_child(player_node)
	return player_node

func _process(_delta: float) -> void:
	if location == "cafe" and player.position.x < 310.0:
		door_sfx.play()
		bell_sfx.play()
		_set_location("street", coffee_street.get_node("PlayerSpawn").position)
	elif location == "street" and player.position.x > 2370.0:
		door_sfx.play()
		bell_sfx.play()
		_set_location("cafe", Vector2(430, 771))
	if location == "street":
		var view_width := get_viewport().get_visible_rect().size.x / camera.zoom.x
		# The camera's own (possibly limit-clamped) position, not the raw
		# player position: near CoffeeExterior the view is already pinned
		# against camera.limit_right, so the sky must stop drifting there
		# too, in step with the buildings that have visibly stopped.
		coffee_street.call("ensure_visible", camera.get_screen_center_position().x - view_width * 0.5)
	if location == "hall":
		_update_environment()
	kas.prompt.visible = location == "hall" and not dialogue.active and not book.active and absf(player.position.x - kas.position.x) <= TALK_DISTANCE
	lina.prompt.visible = location == "hall" and quest_unlocked and not dialogue.active and not book.active and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE
	diana.get_node("Prompt").visible = location == "street" and walk_quest_active and not diana_met and not dialogue.active and not book.active and absf(player.position.x - _diana_talk_x()) <= TALK_DISTANCE
	if location == "hall" and player.position.x >= 2250 and not dialogue.active and not book.active:
		room_title.reveal()

func _update_environment() -> void:
	# Retain the left and vertical framing limits, but never hit a right wall.
	camera.limit_right = maxi(camera.limit_right, ceili(player.global_position.x + 10000.0))
	var view_width := get_viewport().get_visible_rect().size.x / camera.zoom.x
	for art in repeating_layers:
		art.update(camera.get_screen_center_position().x, view_width)

func _connect_hotspot(node_name: String, dialogue_id: String) -> void:
	var hotspot: Area2D = coffee_interior.get_node(node_name)
	hotspot.activated.connect(_on_hotspot_clicked.bind(dialogue_id))
	hotspots.append(hotspot)

func _set_hotspots_enabled(value: bool) -> void:
	for hotspot in hotspots:
		hotspot.set_enabled(value)

func _on_hotspot_clicked(dialogue_id: String) -> void:
	if location == "cafe" and diana_met and not dialogue.active and not book.active and not transitioning:
		dialogue.start(dialogue_id)

func _diana_talk_x() -> float:
	# Her Body/CollisionShape2D has been dragged to line up with the artwork
	# (both offset far from the Diana node's own origin), so that's where
	# the player actually gets stopped — measure proximity from there.
	return diana.get_node("Body/CollisionShape2D").global_position.x

func try_talk() -> void:
	if book.active or transitioning or dialogue.active or intro_active:
		return
	if location == "hall":
		if absf(player.position.x - kas.position.x) <= TALK_DISTANCE:
			dialogue.start("kas_return" if dialogue.lina_resolved and not dialogue.followup_completed else "kas")
		elif quest_unlocked and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE:
			dialogue.start("lina")
	elif location == "street":
		if walk_quest_active and not diana_met and absf(player.position.x - _diana_talk_x()) <= TALK_DISTANCE:
			dialogue.start("diana")

func _conversation_started() -> void:
	quest_label.hide()
	book_hint.hide()
	if dialogue.conversation_id == "lina":
		book.lina_known = true
		quest_label.text = "Задание: выслушать Лину и решить её судьбу"
	player.controls_locked = true
	player.velocity.x = 0.0
	var target: Node2D = lina if dialogue.conversation_id == "lina" else kas if dialogue.conversation_id.begins_with("kas") else null
	if target != null:
		player.artwork.flip_h = player.position.x > target.position.x
	player.artwork.play("idle")
	if target == kas:
		kas.set_conversing(true, player.global_position.x)
	controls.hide()
	mobile_controls.set_gameplay_visible(false)
	travel_button.hide()

func _refresh_quest_label() -> void:
	if diana_met:
		quest_label.text = "Задание: порадовать Точку"
	elif walk_quest_active:
		quest_label.text = "Задание: прогуляться"
	elif dialogue.followup_completed:
		quest_label.text = "Задание выполнено: вернуться в Точку" if point_visited else "Задание: вернуться в Точку"
	elif dialogue.lina_resolved:
		quest_label.text = "Задание: вернуться к Касу"
		kas.prompt.text = "E — вернуться к Касу"

func _conversation_finished() -> void:
	player.controls_locked = false
	kas.set_conversing(false)
	controls.visible = not mobile_controls.mobile_enabled
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	if dialogue.conversation_id == "point":
		walk_quest_active = true
	elif dialogue.conversation_id == "diana":
		diana_met = true
		book.diana_known = true
		_set_hotspots_enabled(true)
	_refresh_quest_label()
	if quest_unlocked:
		book_hint.text = "J — книга душ" if book_seen else "Новая книга душ · Нажми J, чтобы открыть досье"
		book_hint.show()
	_update_travel_button()
	if dialogue.followup_completed and not quest_toast_shown:
		quest_toast_shown = true
		quest_toast.show()
		var tween := create_tween()
		tween.tween_property(quest_toast, "modulate:a", 1.0, 0.5)
		tween.tween_interval(3.0)
		tween.tween_property(quest_toast, "modulate:a", 0.0, 0.8)
		tween.tween_callback(quest_toast.hide)

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
	travel_button.hide()

func _book_closed() -> void:
	player.controls_locked = false
	controls.visible = not mobile_controls.mobile_enabled
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	book_hint.text = "J — книга душ"
	book_hint.show()
	_update_travel_button()

func _followup_finished() -> void:
	quest_label.text = "Задание: вернуться в Точку"
	kas.prompt.text = "E — поговорить с Касом"
	_update_travel_button()

func _create_travel_button() -> void:
	travel_button = Button.new()
	travel_button.name = "TravelButton"
	travel_button.set_anchor(SIDE_LEFT, 1.0)
	travel_button.set_anchor(SIDE_RIGHT, 1.0)
	travel_button.add_theme_font_size_override("font_size", 16)
	travel_button.add_theme_color_override("font_color", Color("f4e5c3"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.08, 0.89)
	style.border_color = Color("c6a875")
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	travel_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.18, 0.15, 0.96)
	travel_button.add_theme_stylebox_override("hover", hover)
	travel_button.add_theme_stylebox_override("pressed", hover)
	travel_button.pressed.connect(travel)
	$Interface.add_child(travel_button)
	_update_travel_button()

func _create_quest_toast() -> void:
	quest_toast = Label.new()
	quest_toast.name = "QuestToast"
	quest_toast.text = "НОВОЕ ЗАДАНИЕ: ВЕРНУТЬСЯ В ТОЧКУ"
	quest_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_toast.size = Vector2(640, 52)
	quest_toast.set_anchor(SIDE_LEFT, 0.5)
	quest_toast.set_anchor(SIDE_RIGHT, 0.5)
	quest_toast.position = Vector2(-320, 107)
	quest_toast.add_theme_font_size_override("font_size", 23)
	quest_toast.add_theme_color_override("font_color", Color("f2ddab"))
	quest_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	quest_toast.add_theme_constant_override("shadow_offset_y", 3)
	quest_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_toast.modulate.a = 0.0
	$Interface.add_child(quest_toast)
	quest_toast.hide()

func _update_travel_button() -> void:
	if travel_button == null:
		return
	travel_button.visible = dialogue.followup_completed and not dialogue.active and not book.active and not transitioning
	if mobile_controls.mobile_enabled:
		travel_button.offset_left = -240
		travel_button.offset_right = -14
		travel_button.offset_top = 16
		travel_button.offset_bottom = 60
		travel_button.add_theme_font_size_override("font_size", 14)
		travel_button.text = "В кофейню" if location == "hall" else "В зал распределения"
	else:
		travel_button.offset_left = -382
		travel_button.offset_right = -22
		travel_button.offset_top = 20
		travel_button.offset_bottom = 68
		travel_button.add_theme_font_size_override("font_size", 16)
		travel_button.text = "Переместиться в кофейню" if location == "hall" else "Переместиться в зал распределения"

func travel() -> void:
	if not dialogue.followup_completed or dialogue.active or book.active or transitioning:
		return
	transitioning = true
	player.controls_locked = true
	_update_travel_button()
	await player.dissolve_out()
	var first_visit := false
	if location == "hall":
		hall_position = player.position
		first_visit = not point_visited
		point_visited = true
		_refresh_quest_label()
		_set_location("cafe", coffee_interior.get_node("CoffeeSpawn").position)
	else:
		_set_location("hall", hall_position)
	await player.dissolve_in()
	player.controls_locked = false
	transitioning = false
	_update_travel_button()
	if first_visit:
		dialogue.start("point")

func _set_location(destination: String, spawn: Vector2) -> void:
	location = destination
	var in_hall := destination == "hall"
	$BackgroundArt.visible = in_hall
	$ForegroundArt.visible = in_hall
	kas.visible = in_hall
	lina.visible = in_hall
	kas.get_node("Body/CollisionShape2D").set_deferred("disabled", not in_hall)
	diana.get_node("Body/CollisionShape2D").set_deferred("disabled", destination != "street")
	coffee_world.visible = not in_hall
	coffee_interior.visible = destination == "cafe"
	coffee_street.visible = destination == "street"
	var art_sprite: AnimatedSprite2D = player.get_node("Artwork")
	var preview: Sprite2D = coffee_street.get_node("PlayerSpawn/DarkPreview") if destination == "street" else coffee_interior.get_node("CoffeeSpawn/DarkPreview") if destination == "cafe" else null
	art_sprite.scale = preview.scale if preview != null else default_player_art_scale
	player.visual_offset = preview.position if preview != null else Vector2.ZERO
	player.get_node("ContactShadow").position = Vector2(0, -1) + player.visual_offset
	player.set_without_cat(destination == "cafe")
	player.outdoor_footsteps = destination == "street"
	player.call("_align_frame")
	player.position = spawn
	player.velocity = Vector2.ZERO
	player.left_boundary = -100000000.0 if destination == "street" else 155.0 if in_hall else 100.0
	player.right_boundary = INF if in_hall or destination == "street" else 1530.0
	var location_zoom: float = 1.0 if in_hall else coffee_interior.get("gameplay_zoom") if destination == "cafe" else coffee_street.get("gameplay_zoom")
	camera.zoom = Vector2.ONE * location_zoom
	camera.position.y = -305.0 if in_hall else -320.0
	camera.limit_left = -100000000 if destination == "street" else 0
	camera.limit_right = 10000000 if in_hall else 1672 if destination == "cafe" else 2700
	camera.limit_top = 0 if in_hall else -200
	camera.limit_bottom = 941 if in_hall else 1100
	camera.reset_smoothing()
	controls.text = "A / D, стрелки — идти     ·     E — поговорить" if in_hall else "A / D, стрелки — идти"
	mobile_controls.set_talk_visible(in_hall)
	hall_music.stream_paused = not in_hall
	if in_hall:
		point_music.stream_paused = true
	else:
		if not point_music.playing:
			point_music.play()
		point_music.stream_paused = false
	_update_travel_button()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		if not dialogue.active and not transitioning and not intro_active:
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
