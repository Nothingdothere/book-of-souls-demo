extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../wastes_quest_previews/%s.png" % name)

func finish_lines(d: Node) -> void:
	while d.active:
		d.advance()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../wastes_quest_previews"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child.get_script() == load("res://scripts/dev_panel.gd"):
			child.hide()
	scene.dialogue.followup_completed = true
	scene.quest_toast_shown = true
	scene.quest_unlocked = true
	scene.book.unlocked = true
	scene.diana_met = true
	scene.point_inspection_started = true
	scene.point_repair_planned = true
	scene.walk_quest_active = true
	scene._set_location("hall", Vector2(350, 771))
	scene._try_point_next_assignment()
	scene.dialogue.advance()
	await shot("kas_assignment")
	finish_lines(scene.dialogue)
	await scene.travel()
	scene.room_title.panel.hide()
	await shot("new_ground_spawn")
	scene.player.position.x = 3600
	scene.camera.reset_smoothing()
	await shot("new_ground_extension")
	scene.player.velocity.x = 180
	scene._update_wastes_warning(15)
	finish_lines(scene.dialogue)
	await scene.travel()
	for frame in range(3):
		await process_frame
	scene.dialogue.advance()
	await shot("kas_return")
	finish_lines(scene.dialogue)
	await scene.travel()
	await shot("repaired_point")
	print("CAPTURE: wastes quest, replaced ground and Point return")
	quit()
