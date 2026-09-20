extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	for x in [1672.0, 3350.0, 8500.0]:
		player.position.x = x
		player.get_node("Camera2D").reset_smoothing()
		for frame in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://../library_extension_" + str(int(x)) + ".png"
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
	quit()
