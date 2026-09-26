extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func check_teleport(scene: Node, destination: String) -> void:
	var old_location: String = scene.location
	check(scene.transitioning and scene.player.controls_locked, "Teleport did not lock controls")
	check(not scene.mobile_controls.gameplay_visible and not scene.travel_button.visible, "Gameplay controls remained active during teleport")
	var guard := 0
	var faded_out := false
	while scene.location == old_location and guard < 120:
		await process_frame
		if scene.location == old_location and scene.player.artwork.modulate.a < 0.5:
			faded_out = true
		guard += 1
	check(faded_out, "Scene switched before Dark visibly disappeared")
	check(scene.location == destination and scene.player.artwork.modulate.a < 0.1, "Dark arrived visible before fade-in")
	check(scene.transitioning and scene.player.controls_locked, "Controls unlocked before appearance finished")
	while scene.transitioning and guard < 240:
		await process_frame
		guard += 1
	check(guard < 240 and is_equal_approx(scene.player.artwork.modulate.a, 1.0), "Teleport did not restore Dark")
	check(not scene.player.controls_locked and scene.mobile_controls.gameplay_visible, "Teleport did not restore controls")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.dialogue.followup_completed = true
	scene.walk_quest_active = true
	scene._set_location("hall", Vector2(700, 771))
	scene.travel()
	await check_teleport(scene, "cafe")
	scene.travel()
	await check_teleport(scene, "hall")
	scene.wastes_quest_unlocked = true
	scene.travel()
	await check_teleport(scene, "other_side")
	scene.travel()
	await check_teleport(scene, "hall")
	var dev: Node
	for child in scene.get_children():
		if child.get_script() == load("res://scripts/dev_panel.gd"):
			dev = child
	check(dev != null, "Debug panel missing")
	if dev != null:
		var buttons: Array = dev.get_child(0).get_child(0).get_children().filter(func(node): return node is Button)
		scene.dialogue.start("kas")
		buttons[3].pressed.emit()
		check(not scene.dialogue.active, "Dev teleport did not close active dialogue")
		buttons[1].pressed.emit()
		await check_teleport(scene, "other_side")
		scene.book.unlocked = true
		scene.book.open()
		buttons[1].pressed.emit()
		check(not scene.book.active, "Dev teleport did not close book")
		await check_teleport(scene, "cafe")
	# Street doors are walked through, with no teleport effect.
	scene.player.smoke_time = -1.0
	scene.player.position.x = 305
	for frame in range(3):
		await process_frame
	check(scene.location == "street" and not scene.transitioning and scene.player.smoke_time < 0, "Walking outdoors started teleport animation")
	check(not scene.player.without_cat, "Walking outdoors lost shoulder cat")
	scene.player.position.x = 2375
	for frame in range(3):
		await process_frame
	check(scene.location == "cafe" and not scene.transitioning and scene.player.smoke_time < 0, "Walking indoors started teleport animation")
	check(scene.player.without_cat, "Walking indoors did not return cat to counter")
	if failures.is_empty():
		print("PASS: hall/Point/wastes teleport fades, dev teleport/duplicate guard/overlay close, control lock/restore and walking doors without smoke")
	quit(0 if failures.is_empty() else 1)
