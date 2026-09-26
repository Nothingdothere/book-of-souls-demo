extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../point_quest_previews/%s.png" % name)

func finish_lines(d: Node) -> void:
	while d.active:
		d.advance()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../point_quest_previews"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child.get_script() == load("res://scripts/dev_panel.gd"):
			child.hide()
	scene.dialogue.followup_completed = true
	scene.quest_unlocked = true
	scene.book.unlocked = true
	scene.diana_met = true
	scene._set_location("cafe", Vector2(1080, 771))
	await process_frame
	scene.dialogue.advance()
	await shot("inspection_intro")
	finish_lines(scene.dialogue)
	for id in ["coffee_hotspot_cat", "coffee_hotspot_wall", "coffee_hotspot_machine"]:
		scene._on_hotspot_clicked(id)
		finish_lines(scene.dialogue)
	await shot("inspection_counter")
	for id in ["coffee_hotspot_garland", "coffee_hotspot_backroom"]:
		scene._on_hotspot_clicked(id)
		finish_lines(scene.dialogue)
	await process_frame
	scene.dialogue.advance()
	scene.dialogue.advance()
	scene.dialogue.advance()
	await shot("repair_dialogue")
	finish_lines(scene.dialogue)
	scene.point_next_assignment_started = true
	scene.complete_point_followup_quest()
	scene._set_location("cafe", Vector2(1080, 771))
	await shot("repaired_interior")
	scene._set_location("other_side", Vector2(1086, 771))
	scene.room_title.panel.hide()
	scene.dialogue.start("other_side_warning")
	finish_lines(scene.dialogue)
	scene.book.lina_known = true
	scene.book.diana_known = true
	scene.book.open()
	scene.book.page = scene.book.page_count() - 1
	scene.book._show_page()
	await shot("arbiter_desktop")
	scene.book.body.add_theme_font_override("normal_font", preload("res://assets/fonts/Caveat.ttf"))
	scene.book.body.add_theme_font_size_override("normal_font_size", 29)
	scene.book.body.add_theme_constant_override("line_separation", 0)
	await shot("arbiter_browser_font")
	print("CAPTURE: Point quest, repaired room and Arbiter dossier")
	quit()
