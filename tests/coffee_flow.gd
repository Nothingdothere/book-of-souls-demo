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
	while dialogue.active and not dialogue.choosing and guard < 200:
		dialogue.advance()
		guard += 1
	check(guard < 200, "Dialogue did not finish")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var dialogue = scene.dialogue
	check(not scene.travel_button.visible, "Coffee travel unlocked before Kas follow-up")
	dialogue.start()
	dialogue.skip_intro()
	dialogue.choose_topic("topic_6")
	finish_lines(dialogue)
	dialogue.close()
	scene.player.position.x = scene.lina.position.x - 100
	scene.try_talk()
	dialogue.skip_intro()
	dialogue._show_verdict()
	dialogue.choose_verdict("rebirth")
	finish_lines(dialogue)
	check(scene.lina.resolved and dialogue.lina_resolved, "Lina did not depart")
	check(scene.quest_label.text == "Задание: вернуться к Касу", "Return-to-Kas objective absent")
	check(not scene.travel_button.visible, "Travel appeared before Kas follow-up")
	scene.player.position.x = scene.kas.position.x + 130
	scene.try_talk()
	check(dialogue.active and dialogue.conversation_id == "kas_return", "Kas follow-up did not open")
	check(dialogue.lines.size() == 11, "Kas follow-up is incomplete")
	check(dialogue.current_speaker == "kas" and dialogue.portrait.position.x < 640, "Kas portrait is on wrong side")
	dialogue.advance()
	dialogue.advance()
	check(dialogue.current_speaker == "dark" and dialogue.portrait.position.x > 640, "Dark portrait is on wrong side")
	dialogue.close()
	check(not dialogue.followup_completed and not scene.travel_button.visible, "Aborted follow-up unlocked travel")
	scene.try_talk()
	finish_lines(dialogue)
	check(dialogue.followup_completed and not dialogue.active, "Kas follow-up did not complete")
	check(scene.quest_label.text == "Задание: вернуться в Точку", "Point objective absent")
	check(scene.travel_button.visible and "кофейню" in scene.travel_button.text, "Coffee button absent")
	scene.book.open()
	check(not scene.travel_button.visible, "Travel button covered the soul book")
	scene.book.close()
	check(scene.travel_button.visible, "Travel button did not return after the soul book")
	var saved_position: Vector2 = scene.player.position
	scene.mobile_controls.set_mobile_enabled(true)
	check(scene.travel_button.visible and scene.travel_button.text == "В кофейню", "Mobile travel button missing")
	scene.travel_button.pressed.emit()
	check(scene.location == "cafe" and scene.coffee_world.visible, "Coffee location did not load")
	check(scene.player.without_cat and not scene.kas.visible, "Hall actors did not switch")
	check(scene.player.artwork.sprite_frames.get_frame_texture(&"idle", 0).get_size() == Vector2(1024, 1536), "No-cat idle canvas was not fixed")
	check(scene.coffee_world.cat.sprite_frames.has_animation("paw") and scene.coffee_world.cat.sprite_frames.has_animation("wash"), "Cat animations missing")
	check("зал распределения" in scene.travel_button.text, "Return button text incorrect")
	check(not scene.mobile_controls.talk_button.visible, "Talk button should not appear away from hall")
	scene.player.position.x = 305
	await process_frame
	check(scene.location == "street" and scene.coffee_world.street.visible, "Walking left did not lead outdoors")
	scene.player.position.x = 2375
	await process_frame
	check(scene.location == "cafe" and scene.coffee_world.interior.visible, "Walking back did not enter cafe")
	scene.travel_button.pressed.emit()
	check(scene.location == "hall" and scene.player.position.distance_to(saved_position) < 1.0, "Return to hall did not restore position")
	check(not scene.player.without_cat and scene.kas.visible and scene.travel_button.visible, "Hall state was not restored")
	check(scene.mobile_controls.talk_button.visible, "Talk button did not return in hall")
	if failures.is_empty():
		print("PASS: Lina departure, Kas follow-up, quest, travel, no-cat Dark, counter cat, street and hall return")
	quit(0 if failures.is_empty() else 1)
