extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var artwork = player.get_node("Artwork")
	for frame in range(10):
		await physics_frame
	var origin: Vector2 = player.position
	if artwork.sprite_frames.get_frame_count("idle") != 8 or not artwork.is_playing():
		push_error("Idle frames or playback missing")
		quit(1)
		return
	var initial_idle_frame: int = artwork.frame
	for frame in range(20):
		await physics_frame
	if artwork.frame == initial_idle_frame or artwork.animation != &"idle":
		push_error("Idle does not advance")
		quit(1)
		return
	Input.action_press("ui_right")
	for frame in range(30):
		await physics_frame
	Input.action_release("ui_right")
	if artwork.animation != &"walk" or artwork.flip_h or artwork.sprite_frames.get_frame_count("walk") != 8:
		push_error("Right animation or supplied frame loading failed")
		quit(1)
		return
	if player.position.x < origin.x + 80.0:
		push_error("Right movement failed")
		quit(1)
		return
	var right_x: float = player.position.x
	Input.action_press("ui_left")
	for frame in range(30):
		await physics_frame
	Input.action_release("ui_left")
	if not artwork.flip_h:
		push_error("Left-facing animation failed")
		quit(1)
		return
	if player.position.x > right_x - 80.0 or absf(player.position.y - origin.y) > 2.0:
		push_error("Left movement or floor collision failed")
		quit(1)
		return
	for frame in range(3):
		await physics_frame
	if artwork.animation != &"idle":
		push_error("Idle transition failed")
		quit(1)
		return
	if not artwork.flip_h:
		push_error("Idle lost the last facing direction")
		quit(1)
		return
	artwork.frame = 7
	for frame in range(20):
		await physics_frame
	if artwork.frame > 1:
		push_error("Idle did not loop")
		quit(1)
		return
	if absf(artwork.position.y - (-202.635)) > 0.01:
		push_error("Idle feet alignment failed")
		quit(1)
		return
	print("PASS: eight idle frames advance and loop, facing retained, feet aligned, walking and collisions valid")
	quit(0)
