extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var kas = scene.get_node("Kas")
	for frame in range(15):
		await physics_frame
	Input.action_press("ui_left")
	for frame in range(220):
		await physics_frame
	Input.action_release("ui_left")
	var stopped_x: float = player.position.x
	if stopped_x < kas.position.x + 108 or stopped_x > kas.position.x + 112:
		push_error("Dark did not stop at Kas's collision boundary")
		quit(1)
		return
	if player.artwork.animation != &"idle":
		push_error("Dark walks in place against Kas")
		quit(1)
		return
	scene.try_talk()
	if not scene.get_node("Dialogue").active:
		push_error("Conversation unavailable at collision boundary")
		quit(1)
		return
	scene.get_node("Dialogue").close()
	Input.action_press("ui_right")
	for frame in range(30):
		await physics_frame
	Input.action_release("ui_right")
	if player.position.x < stopped_x + 80:
		push_error("Dark cannot walk away from Kas")
		quit(1)
		return
	print("PASS: Kas blocks passage, blocked player idles, dialogue remains reachable, retreat works")
	quit(0)
