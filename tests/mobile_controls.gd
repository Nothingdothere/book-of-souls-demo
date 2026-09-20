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
	var mobile = scene.mobile_controls
	var player = scene.player
	mobile.set_mobile_enabled(true)
	check(mobile.root_control.visible and not scene.controls.visible, "Mobile HUD did not replace keyboard help")
	var buttons: Array[Node] = mobile.root_control.find_children("*", "Button", true, false)
	check(buttons.size() == 4, "Expected four touch buttons")
	var right: Button
	var talk: Button
	for button in buttons:
		if button.text == "▶":
			right = button
		if button.text.begins_with("E"):
			talk = button
	var start_x: float = player.position.x
	right.button_down.emit()
	for frame in range(12):
		await physics_frame
	right.button_up.emit()
	check(player.position.x > start_x + 20, "Touch movement failed")
	player.position.x = scene.kas.position.x + 130
	talk.pressed.emit()
	check(scene.dialogue.active and not mobile.root_control.visible, "Touch interaction failed or HUD covered dialogue")
	var index_before: int = scene.dialogue.line_index
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(640, 500)
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	root.push_input(touch, true)
	await process_frame
	check(scene.dialogue.line_index > index_before or not scene.dialogue.is_revealing(), "Touch did not advance dialogue")
	scene.dialogue.close()
	check(mobile.root_control.visible, "Mobile HUD did not return after dialogue")
	scene._topic_finished("kas", "topic_6")
	mobile.book_button.pressed.emit()
	check(scene.book.active and not mobile.root_control.visible, "Touch book button failed")
	var page_touch := InputEventScreenTouch.new()
	page_touch.position = scene.book.stage.get_global_transform() * Vector2(1100, 500)
	page_touch.pressed = true
	root.push_input(page_touch, true)
	await process_frame
	check(scene.book.turning, "Touch did not turn book page")
	scene.book.close()
	check(mobile.root_control.visible, "Mobile HUD did not return after book")
	if failures.is_empty():
		print("PASS: mobile HUD, touch movement, interaction, dialogue, book and visibility")
	quit(0 if failures.is_empty() else 1)
