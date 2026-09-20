extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var d = scene.get_node("Dialogue")
	var p = scene.get_node("Player")
	var npc = scene.get_node("Kas")
	for frame in range(10):
		await physics_frame
	scene.try_talk()
	check(not d.active, "Conversation opened out of range")
	check(npc.artwork.animation == &"front" and not npc.artwork.flip_h, "Kas should wait facing front")
	p.position.x = npc.position.x + 130
	scene.try_talk()
	check(d.active and p.controls_locked, "Interaction failed to open/lock movement")
	check(npc.artwork.animation == &"side" and not npc.artwork.flip_h, "Kas should face Dark approaching from the right")
	check(absf(npc.artwork.position.x + 5.7) < 0.01, "Kas registration shifted")
	check(not d.portrait.visible and d.current_speaker == "", "Narration incorrectly displays portrait")
	check(d.body.visible_characters == 0, "Typewriter did not start at zero")
	await create_timer(0.12).timeout
	check(d.body.visible_characters > 0 and d.is_revealing(), "Typewriter failed to progress")
	var start_x: float = p.position.x
	Input.action_press("ui_right")
	for frame in range(8):
		await physics_frame
	Input.action_release("ui_right")
	check(absf(p.position.x - start_x) < 0.1, "Player moved during dialogue")
	# Exercise actual mouse input, not just controller methods.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(650, 555)
	click.global_position = click.position
	Input.parse_input_event(click)
	await process_frame
	await process_frame
	check(not d.is_revealing() and d.line_index == 0, "Click failed to reveal without skipping narration")
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	Input.parse_input_event(click)
	await process_frame
	await process_frame
	Input.parse_input_event(release)
	check(d.current_speaker == "kas" and d.portrait.visible and d.portrait.position.x < 640 and d.portrait.flip_h, "Kas portrait should face inward from left")
	d.advance()
	d.advance()
	check(d.current_speaker == "dark" and d.portrait.visible and d.portrait.position.x > 640 and d.portrait.flip_h, "Dark portrait should face inward from right")
	var guard := 0
	while not d.choosing and guard < 30:
		d.advance()
		guard += 1
	check(d.choosing and d.choices.get_child_count() == 7, "Six topics and exit are not available")
	var verified_entries := 4
	for topic in d.data["topics"]:
		d.choose_topic(topic["id"])
		check(not d.choosing and d.current_topic == topic["id"], "Topic selection failed")
		guard = 0
		while not d.choosing and guard < 80:
			d.advance()
			guard += 1
		check(d.choosing and d.visited.has(topic["id"]), "Topic failed to return to choices")
		verified_entries += topic["lines"].size()
	check(verified_entries == 48 and d.visited.size() == 6, "Not all original dialogue branches were traversed")
	# Exit through the actual choice button signal.
	d.choices.get_child(d.choices.get_child_count() - 1).pressed.emit()
	check(not d.active and not p.controls_locked and npc.artwork.animation == &"front" and not npc.artwork.flip_h, "Exit did not restore front-facing idle")
	p.position.x = npc.position.x + 130
	scene.try_talk()
	check(npc.artwork.animation == &"side" and not npc.artwork.flip_h, "Kas should face Dark on his right")
	check(absf(npc.artwork.position.x + 5.7) < 0.01, "Right-facing Kas registration shifted")
	check(d.active and not d.portrait.visible, "Reopening failed to reset narration")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not d.active and not p.controls_locked, "Escape did not close conversation")
	check(npc.artwork.animation == &"front" and not npc.artwork.flip_h, "Escape did not restore front-facing idle")
	if failures.is_empty():
		print("PASS: proximity, NPC animation, movement lock, typewriter, mouse reveal/advance, both portraits, 48 entries across six topics, exit, reopen, Escape")
	quit(0 if failures.is_empty() else 1)
