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
	var world = scene.other_side
	scene._set_location("other_side", world.get_node("PlayerSpawn").position)
	await physics_frame
	check(scene.lina.collision.disabled, "Hidden Lina blocks the wastes")
	var samples: Array[Vector2] = []
	var near_positions: Array[Vector2] = []
	for x in [1300.0, 1400.0, 1300.0]:
		scene.player.position.x = x
		scene.camera.reset_smoothing()
		for frame in range(4):
			await physics_frame
			await process_frame
		var camera_x: float = scene.camera.get_screen_center_position().x
		samples.append(Vector2(camera_x, world.background.position.x))
		near_positions.append(world.get_node("Midground").position)
	var camera_travel := samples[1].x - samples[0].x
	var background_travel := samples[1].y - samples[0].y
	check(camera_travel > 90 and background_travel > 10 and background_travel < camera_travel, "Distant background did not move more slowly than the ground")
	check(near_positions[0] == near_positions[1], "Parallax moved a nearer layer")
	check(absf(samples[0].y - samples[2].y) < 0.1, "Backdrop drift accumulated when returning")
	var pool_size: int = world.get_child_count()
	for x in [100.0, 2100.0, 3800.0, 9000.0, 50000.0, 1300.0]:
		scene.player.position.x = x
		scene.camera.reset_smoothing()
		for frame in range(4):
			await physics_frame
			await process_frame
		var camera_x: float = scene.camera.get_screen_center_position().x
		var view_width: float = root.get_visible_rect().size.x / scene.camera.zoom.x
		check(scene.player.position.x >= x - 1, "Old right boundary stopped the player")
		check(scene.player.is_on_floor(), "Floor missing in wastes at " + str(x))
		check_coverage(world, camera_x, view_width)
		check(world.get_child_count() == pool_size, "Infinite wastes keep allocating sprites")
	world._update_art(50000.0, 2500.0)
	check_coverage(world, 50000.0, 2500.0)
	# Walk across the hidden hall NPC's position rather than teleport past it.
	scene.player.position.x = 2950
	Input.action_press("ui_right")
	for frame in range(110):
		await physics_frame
	Input.action_release("ui_right")
	check(scene.player.position.x > 3250, "Hidden hall NPC blocks walking right")
	scene._set_location("hall", Vector2(687, 771))
	scene._set_location("other_side", world.get_node("PlayerSpawn").position)
	check(not scene.other_side_warning_shown and scene.other_side_walk_time == 0, "Warning did not reset for another visit")
	for frame in range(10):
		await physics_frame
	check(scene.other_side_walk_time == 0, "Standing still counts as walking")
	Input.action_press("ui_right")
	for frame in range(840):
		await physics_frame
	check(not scene.dialogue.active and scene.other_side_walk_time < 15, "Warning appeared too early")
	var guard := 0
	while not scene.dialogue.active and guard < 120:
		await physics_frame
		guard += 1
	check(scene.dialogue.active and scene.dialogue.conversation_id == "other_side_warning", "15 seconds of walking did not show warning")
	check(scene.other_side_walk_time >= 15 and scene.other_side_walk_time < 15.1, "Wrong warning timing")
	check(not scene.dialogue.portrait.visible and "владения Арбитра" in scene.dialogue.body.text and scene.player.controls_locked, "Warning text, portrait or movement lock incorrect")
	var paused_time: float = scene.other_side_walk_time
	scene._update_wastes_warning(10.0)
	check(scene.other_side_walk_time == paused_time, "Dialogue counts as walking")
	scene.dialogue.advance()
	scene.dialogue.advance()
	for frame in range(60):
		await physics_frame
	Input.action_release("ui_right")
	check(not scene.dialogue.active and not scene.player.controls_locked, "Warning repeated or prevented continued exploration")
	if failures.is_empty():
		print("PASS: distant parallax, infinite art/floor/camera, bounded sprite pool, hidden NPC collision, wide-screen coverage and 15-second once-per-visit warning")
	quit(0 if failures.is_empty() else 1)

func check_coverage(world: Node2D, camera_x: float, view_width: float) -> void:
	for art in world.repeating_layers:
		var first: Sprite2D = art.sprites[0]
		var last: Sprite2D = art.sprites[-1]
		var left := first.position.x + first.get_rect().position.x * first.scale.x
		var right := last.position.x + last.get_rect().end.x * last.scale.x
		check(left <= camera_x - view_width * 0.5 + 0.1 and right >= camera_x + view_width * 0.5 - 0.1, "Blank edge in " + first.name)
