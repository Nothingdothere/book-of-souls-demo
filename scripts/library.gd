extends Node2D

signal next_assignment_requested

@onready var camera: Camera2D = $Player/Camera2D
@onready var distant_view: Sprite2D = $BackgroundArt/DistantView
@onready var foreground: Sprite2D = $ForegroundArt/Books
@onready var player: CharacterBody2D = $Player
@onready var kas: Node2D = $Kas
@onready var fate: Node2D = $Fate
@onready var dialogue: CanvasLayer = $Dialogue
const TALK_DISTANCE := 170.0
const POINT_HOTSPOT_COUNT := 5
const RepeatingArt := preload("res://scripts/repeating_art.gd")
var repeating_layers: Array = []
var lina: Node2D
var room_title: CanvasLayer
var book: CanvasLayer
var quest_unlocked := false
var book_seen := false
var quest_label: Label
var book_icon: TextureButton
var book_icon_fx: Control
var book_alert_label: Label
var book_has_new_entry := false
var mobile_controls: CanvasLayer
var coffee_world: Node2D
var coffee_interior: Node2D
var coffee_street: Node2D
var other_side: Node2D
var other_side_walk_time := 0.0
var other_side_warning_shown := false
var fate_encountered := false
var fate_in_range := false
var default_player_art_scale := Vector2(0.285, 0.285)
var travel_button: Button
var location := "hall"
var hall_position := Vector2(687, 771)
var point_visited := false
var walk_quest_active := false
var diana_met := false
var point_inspection_started := false
var point_inspected: Dictionary = {}
var point_repair_planned := false
var point_repair_ready := false
var point_repaired := false
var point_repair_praised := false
var point_next_assignment_requested := false
var point_next_assignment_started := false
var point_next_assignment_in_progress := false
var point_next_assignment_in_range := false
var point_next_assignment_dialogue := "kas_wastes"
var point_next_assignment_objective := "осмотреть переход на Той-стороне"
var wastes_quest_unlocked := false
var wastes_quest_inspected := false
var wastes_quest_completed := false
var wastes_return_in_range := false
var diana: Node2D
var hotspots: Array = []
var transitioning := false
var intro_active := false
var quest_toast: Label
var quest_toast_shown := false
var hall_music: AudioStreamPlayer
var point_music: AudioStreamPlayer
var other_side_music: AudioStreamPlayer
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
	other_side = preload("res://scenes/other_side.tscn").instantiate()
	add_child(other_side)
	other_side.hide()
	fate.hide()
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
	var audio_controls := CanvasLayer.new()
	audio_controls.name = "AudioControls"
	audio_controls.set_script(preload("res://scripts/audio_controls.gd"))
	add_child(audio_controls)
	_create_quest_toast()
	quest_label = _hud_label(Vector2(26, 60), 18)
	quest_label.text = "Задание: поговорить с Касом"
	_style_book_handwriting(quest_label, 24)
	_create_book_icon()
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
	# This recording is 11.64 dB quieter than hall_theme; match the hall's
	# ambient loudness instead of applying the same gain to both files.
	other_side_music = _looping_player("res://assets/audio/music/other_side_theme.mp3", -21.4)
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

func _process(delta: float) -> void:
	if not transitioning and not dialogue.active and not book.active and not intro_active:
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
	elif location == "other_side":
		camera.limit_right = maxi(camera.limit_right, ceili(player.global_position.x + 10000.0))
		_update_wastes_warning(delta)
	_update_fate()
	_try_point_next_assignment()
	_try_wastes_return_dialogue()
	kas.prompt.visible = location == "hall" and not dialogue.active and not book.active and absf(player.position.x - kas.position.x) <= TALK_DISTANCE
	lina.prompt.visible = location == "hall" and quest_unlocked and not dialogue.active and not book.active and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE
	diana.get_node("Prompt").visible = location == "street" and walk_quest_active and not diana_met and not dialogue.active and not book.active and absf(player.position.x - _diana_talk_x()) <= TALK_DISTANCE
	if location == "hall" and player.position.x >= 2250 and not dialogue.active and not book.active:
		room_title.reveal("Читальный зал")

func _update_wastes_warning(delta: float) -> void:
	if other_side_warning_shown or dialogue.active or book.active or transitioning or intro_active or player.controls_locked:
		return
	if player.velocity.x <= 0.0:
		return
	other_side_walk_time += delta
	if other_side_walk_time >= 15.0:
		other_side_warning_shown = true
		dialogue.start("other_side_warning")

func _update_environment() -> void:
	# Retain the left and vertical framing limits, but never hit a right wall.
	camera.limit_right = maxi(camera.limit_right, ceili(player.global_position.x + 10000.0))
	var view_width := get_viewport().get_visible_rect().size.x / camera.zoom.x
	for art in repeating_layers:
		art.update(camera.get_screen_center_position().x, view_width)

func _fate_available() -> bool:
	return dialogue.lina_resolved and lina.resolved and lina.departure_time >= 1.8

func _update_fate() -> void:
	var available := location == "hall" and _fate_available()
	fate.visible = available
	var collision: CollisionShape2D = fate.get_node("Body/CollisionShape2D")
	if collision.disabled == available:
		collision.set_deferred("disabled", not available)
	if not available or absf(player.global_position.x - fate.global_position.x) > TALK_DISTANCE:
		fate_in_range = false
	elif not fate_encountered and not fate_in_range and not dialogue.active and not book.active and not transitioning and not intro_active:
		fate_in_range = true
		dialogue.start("fate")

func _connect_hotspot(node_name: String, dialogue_id: String) -> void:
	var hotspot: Area2D = coffee_interior.get_node(node_name)
	hotspot.set_meta("dialogue_id", dialogue_id)
	hotspot.activated.connect(_on_hotspot_clicked.bind(dialogue_id))
	hotspots.append(hotspot)

func _set_hotspots_enabled(value: bool) -> void:
	for hotspot in hotspots:
		var id: String = hotspot.get_meta("dialogue_id")
		var available := diana_met and point_inspection_started and (not point_repair_planned or point_repaired)
		if point_repaired and id == "coffee_hotspot_wall":
			available = false
		hotspot.set_inspected(point_inspected.has(id) and not point_repaired)
		hotspot.set_enabled(value and available)

func _on_hotspot_clicked(dialogue_id: String) -> void:
	if location != "cafe" or not diana_met or not point_inspection_started or dialogue.active or book.active or transitioning or intro_active:
		return
	if point_repaired:
		if dialogue_id != "coffee_hotspot_wall":
			dialogue.start(dialogue_id)
		return
	if point_repair_planned:
		return
	# After an interrupted final conversation any of the five spots can
	# reopen it. Inspection progress survives leaving the room or pressing Esc.
	if point_inspected.size() == POINT_HOTSPOT_COUNT:
		_begin_point_repair_dialogue()
		return
	point_inspected[dialogue_id] = true
	_refresh_quest_label()
	dialogue.start(dialogue_id)

func _try_point_entry_dialogue() -> void:
	if location != "cafe" or not diana_met or dialogue.active or book.active or transitioning or intro_active:
		return
	if point_repaired and not point_repair_praised:
		dialogue.start("point_repaired")
	elif not point_inspection_started:
		dialogue.start("point_inspection")
	elif not point_repair_planned and point_inspected.size() == POINT_HOTSPOT_COUNT:
		_begin_point_repair_dialogue()

func _begin_point_repair_dialogue() -> void:
	if location == "cafe" and not dialogue.active and not book.active and not transitioning and not point_repair_planned:
		dialogue.start("point_repair")

func _try_point_next_assignment() -> void:
	if location != "hall" or absf(player.position.x - kas.position.x) > TALK_DISTANCE:
		point_next_assignment_in_range = false
		return
	if not point_repair_planned or point_next_assignment_started or point_next_assignment_in_progress or dialogue.active or book.active or transitioning or intro_active:
		return
	# Future assignments can still replace the default via this hook.
	if not point_next_assignment_requested:
		point_next_assignment_requested = true
		next_assignment_requested.emit()
	if not point_next_assignment_dialogue.is_empty() and not point_next_assignment_in_range:
		point_next_assignment_in_range = true
		point_next_assignment_in_progress = true
		dialogue.start(point_next_assignment_dialogue)

func configure_point_followup(dialogue_id: String, objective: String) -> void:
	point_next_assignment_dialogue = dialogue_id
	point_next_assignment_objective = objective

func _try_wastes_return_dialogue() -> void:
	if location != "hall" or absf(player.position.x - kas.position.x) > TALK_DISTANCE:
		wastes_return_in_range = false
		return
	if not wastes_quest_unlocked or not wastes_quest_inspected or wastes_quest_completed or wastes_return_in_range or dialogue.active or book.active or transitioning or intro_active:
		return
	wastes_return_in_range = true
	dialogue.start("kas_wastes_return")

func complete_point_followup_quest() -> void:
	# Call from the next quest's completion event, not merely when leaving
	# the cafe or finishing its opening conversation.
	if point_repair_planned and point_next_assignment_started and not point_repaired:
		point_repair_ready = true
		_refresh_quest_label()

func _apply_point_repair_on_return() -> void:
	if not point_repair_ready or point_repaired:
		return
	point_repaired = true
	point_repair_ready = false
	coffee_interior.set_repaired(true)
	_refresh_quest_label()

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
			if wastes_quest_unlocked and wastes_quest_inspected and not wastes_quest_completed:
				wastes_return_in_range = false
				_try_wastes_return_dialogue()
			elif point_repair_planned and not point_next_assignment_started:
				point_next_assignment_in_range = false
				_try_point_next_assignment()
			else:
				dialogue.start("kas_return" if dialogue.lina_resolved and not dialogue.followup_completed else "kas")
		elif quest_unlocked and not lina.resolved and absf(player.position.x - lina.position.x) <= TALK_DISTANCE:
			dialogue.start("lina")
		elif _fate_available() and not fate_encountered and absf(player.global_position.x - fate.global_position.x) <= TALK_DISTANCE:
			fate_in_range = true
			dialogue.start("fate")
	elif location == "street":
		if walk_quest_active and not diana_met and absf(player.position.x - _diana_talk_x()) <= TALK_DISTANCE:
			dialogue.start("diana")

func _conversation_started() -> void:
	_set_hotspots_enabled(false)
	quest_label.hide()
	book_icon.hide()
	book_alert_label.hide()
	if dialogue.conversation_id == "other_side_warning" and not book.arbiter_known:
		book.arbiter_known = true
		_flag_new_book_entry()
	if dialogue.conversation_id == "other_side_warning" and wastes_quest_unlocked and not wastes_quest_completed:
		wastes_quest_inspected = true
		_refresh_quest_label()
	if dialogue.conversation_id == "lina":
		book.lina_known = true
		_flag_new_book_entry()
		quest_label.text = "Задание: выслушать Лину и решить её судьбу"
	player.controls_locked = true
	player.velocity.x = 0.0
	var target: Node2D = lina if dialogue.conversation_id == "lina" else fate if dialogue.conversation_id == "fate" else kas if dialogue.conversation_id.begins_with("kas") else null
	if target != null:
		player.artwork.flip_h = player.position.x > target.position.x
	player.artwork.play("idle")
	if target == kas:
		kas.set_conversing(true, player.global_position.x)
	mobile_controls.set_gameplay_visible(false)
	travel_button.hide()

func _refresh_quest_label() -> void:
	if point_repaired:
		quest_label.text = "Задание выполнено: порадовать Точку"
	elif point_repair_ready:
		quest_label.text = "Задание: вернуться в Точку"
	elif wastes_quest_unlocked and not wastes_quest_completed:
		quest_label.text = "Задание: вернуться к Касу" if wastes_quest_inspected else "Задание: " + point_next_assignment_objective
	elif point_next_assignment_started and not point_next_assignment_objective.is_empty():
		quest_label.text = "Задание: " + point_next_assignment_objective
	elif point_repair_planned:
		quest_label.text = "Задание: вернуться к Касу"
		kas.prompt.text = "E — поговорить с Касом"
	elif diana_met:
		quest_label.text = "Задание: порадовать Точку (%d/%d)" % [point_inspected.size(), POINT_HOTSPOT_COUNT]
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
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	if dialogue.conversation_id == "point" and dialogue.conversation_completed:
		walk_quest_active = true
		room_title.reveal("Точка перехода")
		_try_point_entry_dialogue.call_deferred()
	elif dialogue.conversation_id == "fate" and dialogue.conversation_completed:
		fate_encountered = true
	elif dialogue.conversation_id == "diana" and dialogue.conversation_completed:
		diana_met = true
		book.diana_known = true
		_flag_new_book_entry()
		_try_point_entry_dialogue.call_deferred()
	elif dialogue.conversation_id == "point_inspection":
		point_inspection_started = true
	elif dialogue.conversation_id == "point_repair" and dialogue.conversation_completed:
		point_repair_planned = true
	elif dialogue.conversation_id == "point_repaired" and dialogue.conversation_completed:
		point_repair_praised = true
	elif dialogue.conversation_id == "kas_wastes_return" and dialogue.conversation_completed:
		wastes_quest_completed = true
		complete_point_followup_quest()
	elif dialogue.conversation_id == point_next_assignment_dialogue and point_repair_planned:
		point_next_assignment_in_progress = false
		if dialogue.conversation_completed:
			point_next_assignment_started = true
			if dialogue.conversation_id == "kas_wastes":
				wastes_quest_unlocked = true
	elif dialogue.conversation_id.begins_with("coffee_hotspot_") and not point_repair_planned and point_inspected.size() == POINT_HOTSPOT_COUNT:
		_begin_point_repair_dialogue.call_deferred()
	_set_hotspots_enabled(location == "cafe" and diana_met and not transitioning)
	_refresh_quest_label()
	if quest_unlocked:
		book_icon.show()
		if book_has_new_entry:
			book_alert_label.show()
			book_icon_fx.set_hovering(true)
	_update_travel_button()
	if dialogue.followup_completed and not quest_toast_shown:
		quest_toast_shown = true
		quest_toast.show()
		var tween := create_tween()
		tween.tween_property(quest_toast, "modulate:a", 1.0, 0.5)
		tween.tween_interval(3.0)
		tween.tween_property(quest_toast, "modulate:a", 0.0, 0.8)
		tween.tween_callback(quest_toast.hide)

func _create_book_icon() -> void:
	book_icon = TextureButton.new()
	book_icon.name = "BookIcon"
	book_icon.texture_normal = preload("res://assets/ui/soul_book_icon/soul_book_icon.png")
	book_icon.ignore_texture_size = true
	book_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	book_icon.set_anchor(SIDE_TOP, 1.0)
	book_icon.set_anchor(SIDE_BOTTOM, 1.0)
	book_icon.offset_left = 26
	book_icon.offset_right = 86
	book_icon.offset_top = -96
	book_icon.offset_bottom = -33
	book_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Which button opens it is left for the player to discover — the tooltip
	# only names the book, not the key.
	book_icon.tooltip_text = "книга душ"
	book_icon.pressed.connect(_toggle_book)
	$Interface.add_child(book_icon)
	book_icon_fx = Control.new()
	book_icon_fx.set_script(preload("res://scripts/hover_sparkles.gd"))
	book_icon_fx.glow_enabled = true
	book_icon_fx.glow_radius = 16.0
	book_icon_fx.sparkle_amount = 6
	book_icon_fx.sparkle_velocity_min = 3.0
	book_icon_fx.sparkle_velocity_max = 8.0
	book_icon_fx.sparkle_scale_min = 0.3
	book_icon_fx.sparkle_scale_max = 0.6
	book_icon.add_child(book_icon_fx)
	book_icon.mouse_entered.connect(func(): book_icon_fx.set_hovering(true))
	# A new-entry alert holds the same glow/sparkles on; leaving with the
	# mouse shouldn't cancel that until the alert itself is cleared.
	book_icon.mouse_exited.connect(func():
		if not book_has_new_entry:
			book_icon_fx.set_hovering(false))
	book_icon.hide()
	book_alert_label = Label.new()
	book_alert_label.text = "Новая запись"
	book_alert_label.set_anchor(SIDE_TOP, 1.0)
	book_alert_label.set_anchor(SIDE_BOTTOM, 1.0)
	book_alert_label.offset_left = 96
	book_alert_label.offset_right = 280
	book_alert_label.offset_top = -96
	book_alert_label.offset_bottom = -33
	book_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	book_alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_book_handwriting(book_alert_label, 22)
	$Interface.add_child(book_alert_label)
	book_alert_label.hide()

func _flag_new_book_entry() -> void:
	if book_has_new_entry:
		return
	book_has_new_entry = true
	if book_icon.visible:
		book_alert_label.show()
		book_icon_fx.set_hovering(true)

func _style_book_handwriting(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", book.handwriting)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4dfa0"))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.82, 0.4, 0.65))
	label.add_theme_constant_override("outline_size", 1)

func _toggle_book() -> void:
	if dialogue.active or transitioning or intro_active:
		return
	if book.active:
		book.close()
	else:
		book.open()

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
		_flag_new_book_entry()
		quest_label.text = "Задание: поговорить с расколотой душой"

func _book_opened() -> void:
	_set_hotspots_enabled(false)
	book_seen = true
	player.controls_locked = true
	player.velocity.x = 0
	player.artwork.play("idle")
	mobile_controls.set_gameplay_visible(false)
	quest_label.hide()
	book_icon.hide()
	# Reading it clears the alert; the next new entry will raise it again.
	book_has_new_entry = false
	book_alert_label.hide()
	book_icon_fx.set_hovering(false)
	travel_button.hide()

func _book_closed() -> void:
	player.controls_locked = false
	mobile_controls.set_gameplay_visible(true)
	quest_label.show()
	book_icon.show()
	_update_travel_button()
	_set_hotspots_enabled(location == "cafe" and diana_met and not dialogue.active and not transitioning)

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
	travel_button.add_theme_color_override("font_hover_color", Color("fff2d2"))
	# Texture margins protect the moon medallions in each corner from
	# stretching; only the plain strip between them stretches to fit
	# whatever length the button's text needs.
	var normal_style := StyleBoxTexture.new()
	normal_style.texture = preload("res://assets/ui/travel_button/travel_button_normal.png")
	normal_style.texture_margin_left = 81
	normal_style.texture_margin_right = 81
	normal_style.texture_margin_top = 16
	normal_style.texture_margin_bottom = 16
	normal_style.content_margin_left = 28
	normal_style.content_margin_right = 28
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	travel_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style := StyleBoxTexture.new()
	hover_style.texture = preload("res://assets/ui/travel_button/travel_button_hover.png")
	hover_style.texture_margin_left = 81
	hover_style.texture_margin_right = 81
	hover_style.texture_margin_top = 16
	hover_style.texture_margin_bottom = 16
	hover_style.content_margin_left = 28
	hover_style.content_margin_right = 28
	hover_style.content_margin_top = 8
	hover_style.content_margin_bottom = 8
	travel_button.add_theme_stylebox_override("hover", hover_style)
	travel_button.add_theme_stylebox_override("pressed", hover_style)
	travel_button.pressed.connect(travel)
	$Interface.add_child(travel_button)
	var fx := Control.new()
	fx.name = "TravelButtonFx"
	fx.set_script(preload("res://scripts/hover_sparkles.gd"))
	travel_button.add_child(fx)
	travel_button.mouse_entered.connect(fx.set_hovering.bind(true))
	travel_button.mouse_exited.connect(fx.set_hovering.bind(false))
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
	_style_book_handwriting(quest_toast, 24)
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
	travel_button.visible = (location != "other_side" or wastes_quest_unlocked) and dialogue.followup_completed and not dialogue.active and not book.active and not transitioning
	var destination := _travel_destination()
	if mobile_controls.mobile_enabled:
		travel_button.offset_left = -240
		travel_button.offset_right = -14
		travel_button.offset_top = 16
		travel_button.offset_bottom = 60
		travel_button.add_theme_font_size_override("font_size", 14)
		travel_button.text = {"cafe": "В Точку", "other_side": "На Ту-сторону", "hall": "В зал распределения"}[destination]
	else:
		travel_button.offset_left = -382
		travel_button.offset_right = -22
		travel_button.offset_top = 20
		travel_button.offset_bottom = 68
		travel_button.add_theme_font_size_override("font_size", 16)
		travel_button.text = {"cafe": "Переместиться в Точку", "other_side": "На Ту-сторону", "hall": "В зал распределения"}[destination]

func _travel_destination() -> String:
	if location != "hall":
		return "hall"
	return "other_side" if wastes_quest_unlocked and not wastes_quest_completed else "cafe"

func travel() -> void:
	if not dialogue.followup_completed or dialogue.active or book.active or transitioning or intro_active:
		return
	var destination := _travel_destination()
	var spawn: Vector2 = hall_position
	var needs_point_greeting := destination == "cafe" and not walk_quest_active
	if destination == "other_side":
		spawn = other_side.get_node("PlayerSpawn").position
	elif destination == "cafe":
		point_visited = true
		spawn = coffee_interior.get_node("CoffeeSpawn").position
	await transition_to(destination, spawn)
	# Leaving a conversation early must not skip the greeting forever.
	if needs_point_greeting:
		dialogue.start("point")

func transition_to(destination: String, spawn: Vector2) -> void:
	if transitioning or intro_active:
		return
	# One teleport path for travel and the dev panel. Close overlays
	# before locking controls; their close handlers normally unlock Dark.
	transitioning = true
	if dialogue.active:
		dialogue.close()
	if book.active:
		book.close()
	if location == "hall" and destination != "hall":
		hall_position = player.position
	_set_hotspots_enabled(false)
	player.controls_locked = true
	player.velocity.x = 0.0
	mobile_controls.set_gameplay_visible(false)
	_update_travel_button()
	await player.dissolve_out()
	_set_location(destination, spawn)
	await player.dissolve_in()
	player.controls_locked = false
	transitioning = false
	mobile_controls.set_gameplay_visible(true)
	_update_travel_button()
	_set_hotspots_enabled(location == "cafe" and diana_met and not book.active)
	_try_point_entry_dialogue()

func _set_location(destination: String, spawn: Vector2) -> void:
	if destination == "other_side" and location != "other_side":
		other_side_walk_time = 0.0
		other_side_warning_shown = false
	location = destination
	var in_hall := destination == "hall"
	$BackgroundArt.visible = in_hall
	$ForegroundArt.visible = in_hall
	kas.visible = in_hall
	lina.visible = in_hall
	lina.collision.set_deferred("disabled", not in_hall or lina.resolved)
	kas.get_node("Body/CollisionShape2D").set_deferred("disabled", not in_hall)
	diana.get_node("Body/CollisionShape2D").set_deferred("disabled", destination != "street")
	coffee_world.visible = destination in ["cafe", "street"]
	coffee_interior.visible = destination == "cafe"
	coffee_street.visible = destination == "street"
	if destination == "cafe":
		_apply_point_repair_on_return()
	other_side.visible = destination == "other_side"
	var art_sprite: AnimatedSprite2D = player.get_node("Artwork")
	var preview: Sprite2D
	match destination:
		"cafe": preview = coffee_interior.get_node("CoffeeSpawn/DarkPreview")
		"street": preview = coffee_street.get_node("PlayerSpawn/DarkPreview")
		"other_side": preview = other_side.get_node("PlayerSpawn/DarkPreview")
	art_sprite.scale = preview.scale if preview != null else default_player_art_scale
	player.visual_offset = preview.position if preview != null else Vector2.ZERO
	player.get_node("ContactShadow").position = Vector2(0, -1) + player.visual_offset
	player.set_without_cat(destination == "cafe")
	player.outdoor_footsteps = destination in ["street", "other_side"]
	player.call("_align_frame")
	player.position = spawn
	player.velocity = Vector2.ZERO
	player.left_boundary = -100000000.0 if destination == "street" else 155.0 if in_hall else 100.0
	player.right_boundary = {"hall": INF, "street": INF, "cafe": 1530.0, "other_side": INF}.get(destination, INF)
	var location_zoom := 1.0
	match destination:
		"cafe": location_zoom = coffee_interior.gameplay_zoom
		"street": location_zoom = coffee_street.gameplay_zoom
		"other_side": location_zoom = other_side.gameplay_zoom
	camera.zoom = Vector2.ONE * location_zoom
	camera.position.y = -305.0 if in_hall else -320.0
	camera.limit_left = -100000000 if destination == "street" else 0
	camera.limit_right = {"hall": 10000000, "cafe": 1672, "street": 2700, "other_side": 10000000}.get(destination, 10000000)
	camera.limit_top = 0 if in_hall else -200
	camera.limit_bottom = 941 if in_hall else 1100
	camera.reset_smoothing()
	mobile_controls.set_talk_visible(destination in ["hall", "street"])
	var selected_music: AudioStreamPlayer = hall_music if in_hall else other_side_music if destination == "other_side" else point_music
	for music in [hall_music, point_music, other_side_music]:
		if music == selected_music:
			if not music.playing:
				music.play()
			music.stream_paused = false
		else:
			music.stream_paused = true
	_set_hotspots_enabled(destination == "cafe" and diana_met and not dialogue.active and not book.active and not transitioning)
	_update_travel_button()
	if destination == "street":
		room_title.reveal("Мир живых")
	elif destination == "other_side":
		room_title.reveal("Та-сторона")
	_update_fate()
	if destination == "cafe":
		_try_point_entry_dialogue.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		_toggle_book()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not dialogue.active:
			try_talk()
			get_viewport().set_input_as_handled()
