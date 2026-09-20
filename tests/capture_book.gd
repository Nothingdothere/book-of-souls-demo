extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../book_previews/" + name + ".png")

func capture() -> void:
	var failures := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../book_previews"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var b = scene.book
	b.unlocked = true
	b.lina_known = true
	b.open()
	for i in range(4):
		b.page = i
		b._show_page()
		for frame in range(3):
			await process_frame
		print("LAYOUT ", i, " ", b.body.get_content_height(), "/", b.body.size.y)
		if b.body.get_content_height() > b.body.size.y:
			failures += 1
		await shot(str(i) + "_" + b.entries[i]["id"])
	b.page = 0
	b._show_page()
	b.turn(1)
	await create_timer(0.25).timeout
	await shot("04_turn")
	quit(0 if failures == 0 else 1)
