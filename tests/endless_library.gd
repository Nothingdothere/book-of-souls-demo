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
	var player = scene.get_node("Player")
	var kas = scene.get_node("Kas")
	var camera = player.get_node("Camera2D")
	for frame in range(15):
		await physics_frame
	var floor_y: float = player.position.y
	# Walk across the former finite floor edge instead of teleporting past it.
	player.position.x = 1600
	Input.action_press("ui_right")
	for frame in range(250):
		await physics_frame
		check(absf(player.position.y - floor_y) < 0.1, "Fell while crossing reading-room transition")
	Input.action_release("ui_right")
	check(player.position.x > 2300, "Could not walk through transition")
	var npc_position: Vector2 = kas.position
	var node_count: int = scene.get_child_count()
	var pool_count := 0
	for art in scene.repeating_layers:
		pool_count += art.sprites.size()
	for x in [1500.0, 1660.0, 3350.0, 8500.0, 50000.0, 3350.0, 850.0]:
		player.position.x = x
		camera.reset_smoothing()
		Input.action_press("ui_right")
		for frame in range(30):
			await physics_frame
		Input.action_release("ui_right")
		check(player.position.x > x + 80.0, "Right movement stopped at " + str(x))
		check(absf(player.position.y - floor_y) < 0.1 and player.is_on_floor(), "Missing floor at " + str(x))
		check(camera.get_screen_center_position().x > x - 120.0, "Camera stopped following at " + str(x))
		check(kas.position == npc_position, "Kas was moved or recycled")
		var count := 0
		var view_left: float = camera.get_screen_center_position().x - 640.0
		var view_right: float = view_left + 1280.0
		for art in scene.repeating_layers:
			count += art.sprites.size()
			var first: Sprite2D = art.sprites[0]
			var last: Sprite2D = art.sprites[-1]
			var covered_left := first.position.x + first.get_rect().position.x * first.scale.x
			var covered_right := last.position.x + last.get_rect().end.x * last.scale.x
			check(covered_left <= view_left and covered_right >= view_right, "Uncovered viewport for " + str(first.name))
			for i in range(1, art.sprites.size()):
				var previous: Sprite2D = art.sprites[i - 1]
				var current: Sprite2D = art.sprites[i]
				check(absf(current.position.x - previous.position.x - art.tile_width) < 0.02, "Gap between art tiles")
				check(current.flip_h != previous.flip_h, "Adjacent art edges are not mirrored")
		check(count == pool_count and scene.get_child_count() == node_count, "Scene grows with distance")
	player.position.x = npc_position.x + 150
	scene.try_talk()
	check(scene.get_node("Dialogue").active, "Could not return to Kas and talk")
	if failures.is_empty():
		print("PASS: movement beyond old edge, continuous floor, camera, seamless tile bounds, constant sprite pool, return to unique Kas")
	quit(0 if failures.is_empty() else 1)
