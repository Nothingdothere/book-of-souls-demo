extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../coffee_previews/" + name + ".png")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../coffee_previews"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.dialogue.followup_completed = true
	scene._followup_finished()
	scene.travel()
	await shot("01_interior")
	scene.player.position.x = 305
	await process_frame
	await shot("02_street_entrance")
	scene.player.position.x = 1050
	await shot("03_street_houses")
	scene._set_location("cafe", Vector2(1080, 771))
	scene.mobile_controls.set_mobile_enabled(true)
	await shot("04_mobile_interior")
	print("CAPTURE: coffee and street")
	quit()
