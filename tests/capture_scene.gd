extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../preview_library.png"
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE: ", error, " ", ProjectSettings.globalize_path(path))
	quit(error)
