extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func finish_lines(d) -> void:
	var guard := 0
	while d.active and not d.choosing and guard < 400:
		d.advance()
		guard += 1
	check(guard < 400, "Dialogue stalled")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var d = scene.dialogue
	var b = scene.book
	var p = scene.player
	p.position.x = 2950
	await physics_frame
	scene.try_talk()
	d.start("lina")
	check(not d.active and not scene.lina.prompt.visible, "Lina accessible before quest")
	await key(KEY_J)
	check(not b.active, "Book accessible before Kas")
	d.start()
	d.close()
	check(not scene.quest_unlocked, "Interrupted conversation unlocked quest")
	d.start()
	check(d.skip_intro_button.visible, "Intro skip button missing after reopen")
	var skip_click := InputEventMouseButton.new()
	skip_click.button_index = MOUSE_BUTTON_LEFT
	skip_click.pressed = true
	skip_click.position = d.skip_intro_button.get_global_transform() * (d.skip_intro_button.size * 0.5)
	root.push_input(skip_click, true)
	skip_click = skip_click.duplicate()
	skip_click.pressed = false
	root.push_input(skip_click, true)
	await process_frame
	check(d.choosing and not d.skip_intro_button.visible and not scene.quest_unlocked, "Skip intro did not reach choices safely")
	d.choose_topic("topic_1")
	d.skip_intro()
	check(not d.choosing and not d.skip_intro_button.visible, "Intro skip bypassed a topic")
	finish_lines(d)
	d.close()
	check(not scene.quest_unlocked, "Unrelated topic unlocked quest")
	d.start()
	finish_lines(d)
	d.choose_topic("topic_6")
	finish_lines(d)
	await key(KEY_J)
	check(not b.active and d.active, "Book overlapped dialogue")
	d.close()
	check(scene.quest_unlocked and b.unlocked and scene.book_hint.visible, "Quest/book tutorial missing")
	check(b.page_count() == 3, "Lina revealed early")
	await key(KEY_J)
	check(b.active and p.controls_locked and scene.book_seen, "J did not open book")
	var x: float = p.position.x
	Input.action_press("ui_right")
	for frame in range(8):
		await physics_frame
	Input.action_release("ui_right")
	check(absf(p.position.x - x) < 0.1, "Player walks while reading")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = b.stage.get_global_transform() * Vector2(1100, 500)
	click.global_position = click.position
	root.push_input(click, true)
	await process_frame
	await process_frame
	check(b.turning, "Page click did not animate")
	b.turn(1)
	await create_timer(0.7).timeout
	check(b.page == 1 and not b.turning and not b.animation.visible and b.contents.visible, "Page turn completion/spam guard failed")
	await create_timer(0.7).timeout
	check(b.page == 1 and not b.turning, "Book did not remain static")
	b.turn(-1)
	await create_timer(0.7).timeout
	check(b.page == 0, "Backward turn failed")
	b.turn(-1)
	check(not b.turning, "Turn before first page")
	b.turn(1)
	await key(KEY_ESCAPE)
	check(not b.active and not p.controls_locked, "Escape during animation failed")
	await key(KEY_J)
	check(b.contents.visible and not b.turning, "Reopen after interrupted turn failed")
	await key(KEY_J)
	scene.try_talk()
	check(d.active and d.conversation_id == "lina" and b.page_count() == 4, "Lina quest/dossier not unlocked")
	d.close()
	b.open()
	b.page = 3
	b._show_page()
	b.turn(1)
	check(not b.turning, "Turn after last page")
	b.close()
	if failures.is_empty():
		print("PASS: quest gating, interrupted Kas, quest topic, book tutorial, J/Esc, click animation, static pages, boundaries, movement lock, Lina dossier")
	quit(0 if failures.is_empty() else 1)
