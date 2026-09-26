extends SceneTree

var scene: Node
var dialogue: Node

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

# Use the engine input path, including touch-to-mouse emulation, rather
# than emitting button signals or invoking hotspot callbacks directly.
func touch_at(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame

func tap(position: Vector2) -> void:
	await touch_at(position, true)
	await touch_at(position, false)

func tap_button(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "Touch target unavailable: " + button.text)
	await process_frame
	await tap(button.get_global_transform_with_canvas() * (button.size * 0.5))

func choose(label: String) -> void:
	await process_frame
	for child in dialogue.choices.get_children():
		if child is Button and label in child.text:
			await tap_button(child)
			return
	check(false, "Dialogue choice unavailable: " + label)

func finish_lines(expected: String) -> void:
	print("Touch dialogue: ", expected)
	check(dialogue.active and dialogue.conversation_id == expected, "Expected dialogue: " + expected)
	var guard := 0
	while dialogue.active and not dialogue.choosing and dialogue.conversation_id == expected and guard < 250:
		await tap(dialogue.stage.get_global_transform_with_canvas() * Vector2(640, 545))
		guard += 1
	check(guard < 250, "Touch dialogue stuck: " + expected)

func settle_camera() -> void:
	for frame in range(3):
		await physics_frame
	scene.camera.reset_smoothing()
	scene.camera.force_update_scroll()
	await process_frame

func talk_at(x: float, expected: String) -> void:
	scene.player.position.x = x
	await settle_camera()
	# Quest follow-ups open automatically when Dark approaches Kas.
	if not dialogue.active:
		await tap_button(scene.mobile_controls.talk_button)
	check(dialogue.active and dialogue.conversation_id == expected, "Touch talk failed: " + expected)
	check(not scene.mobile_controls.root_control.visible, "Movement HUD obscures dialogue")

func travel_to(expected: String) -> void:
	await tap_button(scene.travel_button)
	var guard := 0
	while scene.transitioning and guard < 240:
		await process_frame
		guard += 1
	await process_frame
	check(not scene.transitioning and scene.location == expected, "Touch travel failed: " + expected)

func inspect(hotspot: Area2D) -> void:
	# Walk the camera to each object, then send a real screen-space tap
	# through GUI routing and physics object picking.
	scene.player.position.x = clampf(hotspot.global_position.x, 430.0, 1400.0)
	await settle_camera()
	var position := hotspot.get_global_transform_with_canvas().origin
	check(root.get_visible_rect().has_point(position), "Hotspot is off-screen: " + hotspot.name)
	await tap(position)
	check(dialogue.active, "Touch hotspot failed: " + hotspot.name)

func verify() -> void:
	if "--phone" in OS.get_cmdline_user_args():
		root.size = Vector2i(852, 393)
	Input.emulate_mouse_from_touch = true
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	dialogue = scene.dialogue
	scene.mobile_controls.set_mobile_enabled(true)
	await settle_camera()
	check(not scene.quest_unlocked, "Lina quest unlocked before Kas")
	await talk_at(scene.kas.position.x + 130, "kas")
	# One tap reveals the current line; emulated mouse must not also skip it.
	var initial_line: int = dialogue.line_index
	await tap(dialogue.stage.get_global_transform_with_canvas() * Vector2(640, 545))
	check(dialogue.line_index == initial_line and not dialogue.is_revealing(), "One touch skipped a line instead of revealing it")
	await tap_button(dialogue.skip_intro_button)
	await choose("Что велела передать Судьба?")
	await finish_lines("kas")
	await choose("Закончить разговор")
	check(scene.quest_unlocked, "Kas touch choice did not unlock Lina")
	await talk_at(scene.lina.position.x - 100, "lina")
	await tap_button(dialogue.skip_intro_button)
	await choose("Вынести решение")
	await choose("на перерождение")
	await finish_lines("lina")
	check(dialogue.lina_resolved, "Touch verdict did not resolve Lina")
	await talk_at(scene.kas.position.x + 130, "kas_return")
	await finish_lines("kas_return")
	await travel_to("cafe")
	await finish_lines("point")
	check(scene.walk_quest_active and "прогуляться" in scene.quest_label.text, "Walk quest missing")
	# Leave on foot using the actual left touch control.
	scene.player.position.x = 320
	await settle_camera()
	var left: Button = scene.mobile_controls.root_control.get_node("MoveLeft")
	var left_position := left.get_global_transform_with_canvas() * (left.size * 0.5)
	await touch_at(left_position, true)
	var guard := 0
	while scene.location != "street" and guard < 40:
		await physics_frame
		guard += 1
	await touch_at(left_position, false)
	check(scene.location == "street", "Touch walking did not exit the Point")
	check(scene.mobile_controls.talk_button.is_visible_in_tree(), "Diana has no mobile talk button on the street")
	await tap_button(scene.mobile_controls.talk_button)
	check(not dialogue.active, "Diana conversation opened outside interaction range")
	await talk_at(scene._diana_talk_x() + 130, "diana")
	dialogue.close()
	check(not scene.diana_met and "прогуляться" in scene.quest_label.text, "Interrupted Diana conversation advanced the quest")
	await talk_at(scene._diana_talk_x() + 130, "diana")
	await finish_lines("diana")
	check(scene.diana_met and "(0/5)" in scene.quest_label.text, "Diana did not advance the walk quest")
	await tap_button(scene.mobile_controls.book_button)
	check(scene.book.active, "Touch book button did not open Diana's dossier")
	await tap(scene.book.stage.get_global_transform_with_canvas() * Vector2(1100, 500))
	await create_timer(0.7).timeout
	check(scene.book.page == 1 and not scene.book.turning, "One touch did not turn exactly one book page")
	for child in scene.book.stage.get_children():
		if child is Button and child.text.begins_with("Закрыть"):
			await tap_button(child)
	check(not scene.book.active and scene.mobile_controls.root_control.visible, "Touch close did not restore controls")
	# Walk back through the door; no developer travel or quest flags.
	scene.player.position.x = 2375
	await settle_camera()
	check(scene.location == "cafe", "Walking back did not enter Point")
	await finish_lines("point_inspection")
	for hotspot in scene.hotspots:
		await inspect(hotspot)
		await finish_lines(dialogue.conversation_id)
	check(scene.point_inspected.size() == 5, "Touch inspection counter did not reach five")
	if not dialogue.active:
		await process_frame
	await finish_lines("point_repair")
	check(scene.point_repair_planned and not "/5" in scene.quest_label.text, "Repair dialogue did not replace the counter")
	await travel_to("hall")
	await talk_at(scene.kas.position.x + 130, "kas_wastes")
	await finish_lines("kas_wastes")
	check(scene.wastes_quest_unlocked, "Kas did not unlock Ta-side quest")
	await travel_to("other_side")
	var right: Button = scene.mobile_controls.root_control.get_node("MoveRight")
	var right_position := right.get_global_transform_with_canvas() * (right.size * 0.5)
	# Speed up the fifteen-second timer while still requiring real movement.
	scene.other_side_walk_time = 14.9
	await touch_at(right_position, true)
	guard = 0
	while not dialogue.active and guard < 60:
		await physics_frame
		guard += 1
	await touch_at(right_position, false)
	check(not Input.is_action_pressed("ui_right"), "Hidden movement control left walking held")
	await finish_lines("other_side_warning")
	check(scene.book.arbiter_known and scene.wastes_quest_inspected, "Warning did not unlock Arbiter and return objective")
	await travel_to("hall")
	await finish_lines("kas_wastes_return")
	check(scene.point_repair_ready and scene.wastes_quest_completed, "Kas return did not queue repair")
	await travel_to("cafe")
	await finish_lines("point_repaired")
	check(scene.point_repaired and scene.point_repair_praised, "Repaired Point quest did not complete")
	check(scene.hotspots.filter(func(h): return h.input_pickable).size() == 4, "Repaired Point does not have four remaining touch targets")
	await inspect(scene.hotspots[0])
	await finish_lines("coffee_hotspot_machine")
	print("PASS: touch-only Kas, Lina verdict, Point, walking, Diana, all five hotspots, repair, Ta-side, Arbiter, Kas return and repaired Point")
	quit(0)
