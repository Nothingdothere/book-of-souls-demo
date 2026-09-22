extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../coffee_previews"))
	for location_name in ["coffee", "street"]:
		var scene: Node2D = load("res://scenes/%s.tscn" % location_name).instantiate()
		root.add_child(scene)
		for frame in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../coffee_previews/f6_%s.png" % location_name)
		scene.queue_free()
		await process_frame
	print("CAPTURE: standalone coffee and street")
	quit()
