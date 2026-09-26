extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func finish_lines(dialogue: Node) -> void:
	var guard := 0
	while dialogue.active and guard < 100:
		dialogue.advance()
		guard += 1
	check(guard < 100, "One-off dialogue did not finish")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var d = scene.dialogue
	check(scene.quest_label.get_theme_font("font") == scene.book.handwriting, "Quest does not use Soul Book handwriting")
	check(not scene.fate.visible and scene.fate.get_node("Body/CollisionShape2D").disabled, "Fate appeared or blocked the hall before Lina departed")
	d.lina_resolved = true
	scene.lina.resolved = true
	scene.lina.departure_time = 1.0
	scene._update_fate()
	check(not scene.fate.visible, "Fate appeared before Lina finished fading")
	scene.lina.departure_time = 3.0
	scene._update_fate()
	await physics_frame
	check(scene.fate.visible and not scene.fate.get_node("Body/CollisionShape2D").disabled, "Fate missing after Lina departed")
	check(scene.fate.position.x > scene.lina.position.x + 170, "Fate is not beyond Lina")
	check(scene.fate.get_node("Artwork").sprite_frames.get_frame_count("idle") == 8, "Fate animation frames missing")
	scene.player.position.x = scene.fate.position.x - 140
	scene._update_fate()
	check(d.active and d.conversation_id == "fate" and scene.player.controls_locked, "Fate proximity dialogue did not start")
	d.close()
	scene._update_fate()
	check(not d.active and not scene.fate_encountered, "Aborted Fate conversation completed or reopened immediately")
	scene.player.position.x -= 200
	scene._update_fate()
	scene.player.position.x += 200
	scene._update_fate()
	d.advance()
	d.advance()
	check(d.current_speaker == "fate" and d.portrait.texture == d.FATE and d.speaker_label.text == "СУДЬБА", "Fate dialogue portrait/name missing")
	finish_lines(d)
	check(scene.fate_encountered and not scene.player.controls_locked, "Fate encounter did not complete")
	scene.player.position.x -= 200
	scene._update_fate()
	scene.player.position.x += 200
	scene._update_fate()
	check(not d.active, "Completed Fate encounter repeated")
	d.followup_completed = true
	scene._update_travel_button()
	await process_frame
	var hall_button_size: Vector2 = scene.travel_button.size
	check("Точку" in scene.travel_button.text and hall_button_size == Vector2(360, 48), "Hall travel name or size incorrect")
	scene._set_location("cafe", Vector2(1080, 771))
	await physics_frame
	await process_frame
	check(not scene.fate.visible and scene.fate.get_node("Body/CollisionShape2D").disabled, "Fate blocks another location")
	check(scene.travel_button.size == hall_button_size and scene.travel_button.get_global_rect().end.x <= 1280, "Point return button grew or overflowed")
	check(not scene.room_title.shown_titles.has("Точка перехода"), "Point title appeared on entry")
	d.start("point")
	d.close()
	check(not scene.walk_quest_active and not scene.room_title.shown_titles.has("Точка перехода"), "Aborted Point greeting advanced the quest/title")
	d.start("point")
	finish_lines(d)
	check(scene.walk_quest_active and scene.room_title.shown_titles.has("Точка перехода"), "Completed Point greeting did not reveal title")
	await create_timer(4.7).timeout
	check(scene.room_title.panel.modulate.a < 0.01, "Point title did not fade out")
	check(not scene.hotspots[0].marker_enabled, "Hotspot guides appeared before their quest")
	scene.diana_met = true
	scene._set_location("cafe", Vector2(1080, 771))
	await process_frame
	check(d.active and d.conversation_id == "point_inspection", "Point inspection intro missing")
	finish_lines(d)
	check(scene.hotspots.all(func(h): return h.marker_enabled and h.input_pickable), "Hotspot guides not enabled for Point quest")
	var click := InputEventScreenTouch.new()
	click.pressed = true
	scene.hotspots[0]._on_input_event(root, click, 0)
	check(d.active and d.conversation_id == "coffee_hotspot_machine", "Touch did not activate hotspot")
	check(scene.hotspots.all(func(h): return not h.marker_enabled), "Hotspot guides remained under dialogue")
	d.close()
	scene.book.unlocked = true
	scene.book.open()
	check(scene.hotspots.all(func(h): return not h.marker_enabled), "Hotspots clickable through Soul Book")
	scene.book.close()
	check(scene.hotspots.all(func(h): return h.marker_enabled), "Hotspot guides did not return after book")
	scene.mobile_controls.set_mobile_enabled(true)
	await process_frame
	var point_mobile_size: Vector2 = scene.travel_button.size
	scene._set_location("hall", Vector2(700, 771))
	await process_frame
	check(point_mobile_size == scene.travel_button.size and point_mobile_size == Vector2(226, 44), "Mobile travel buttons have different sizes")
	scene._set_location("other_side", scene.other_side.get_node("PlayerSpawn").position)
	await physics_frame
	await process_frame
	check(scene.other_side.visible and not scene.coffee_world.visible and not scene.get_node("BackgroundArt").visible, "Other Side overlaps another world")
	check(scene.player.outdoor_footsteps and not scene.player.without_cat, "Other Side footsteps/cat incorrect")
	check(not scene.travel_button.visible, "Other Side has a normal-game travel route")
	check(not scene.other_side.get_node("PlayerSpawn/DarkPreview").visible, "Other Side editor preview appeared in game")
	check(scene.other_side_music.playing and not scene.other_side_music.stream_paused and scene.hall_music.stream_paused and scene.point_music.stream_paused, "Music overlap or wrong selected track")
	check(is_equal_approx(scene.other_side_music.volume_db, -21.4), "Other Side loudness not calibrated")
	for i in range(90):
		await physics_frame
	var floor_collision: CollisionShape2D = scene.get_node("Ground/CollisionShape2D")
	var floor_y: float = floor_collision.global_position.y - floor_collision.shape.distance
	check(scene.player.is_on_floor() and absf(scene.player.position.y - floor_y) < 2, "Other Side player fell through floor")
	scene._set_location("hall", Vector2(700, 771))
	check(scene.other_side_music.stream_paused and not scene.hall_music.stream_paused, "Other Side music did not pause on return")
	for child in scene.get_children():
		if child.get_script() == load("res://scripts/dev_panel.gd"):
			var texts: Array[String] = []
			for control in child.get_child(0).get_child(0).get_children():
				if control is Button:
					texts.append(control.text)
			check(texts == ["Зал распределения", "Точка", "Улица", "Та-сторона"], "Dev panel has extra/missing entries")
	if failures.is_empty():
		print("PASS: Fate gates/portrait/encounter, Other Side floor/audio/dev route, Point title, handwriting, fixed travel sizes and quest-only touch hotspots")
	quit(0 if failures.is_empty() else 1)
