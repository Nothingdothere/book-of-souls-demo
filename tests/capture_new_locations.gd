extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../new_location_previews/%s.png" % name)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../new_location_previews"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child.get_script() == load("res://scripts/dev_panel.gd"):
			child.hide()
	scene.dialogue.followup_completed = true
	scene._set_location("other_side", scene.other_side.get_node("PlayerSpawn").position)
	scene.room_title.panel.hide()
	await shot("other_side")
	scene.player.position.x = 3600
	scene.camera.reset_smoothing()
	await shot("other_side_extension")
	scene.dialogue.start("other_side_warning")
	scene.dialogue.advance()
	await shot("other_side_warning")
	scene.dialogue.close()
	scene._set_location("cafe", Vector2(1000, 771))
	scene.diana_met = true
	scene.point_inspection_started = true
	scene._refresh_quest_label()
	scene._set_hotspots_enabled(true)
	await shot("point_hotspots")
	scene.mobile_controls.set_mobile_enabled(true)
	await shot("point_mobile")
	scene.mobile_controls.set_mobile_enabled(false)
	scene.dialogue.lina_resolved = true
	scene.lina.resolved = true
	scene.lina.departure_time = 3.0
	scene.lina.artwork.hide()
	scene._set_location("hall", Vector2(3840, 771))
	await shot("fate_in_hall")
	scene.player.position.x = 3960
	scene._update_fate()
	scene.dialogue.advance()
	scene.dialogue.advance()
	scene.dialogue.body.visible_characters = -1
	await shot("fate_dialogue")
	print("CAPTURE: new locations and Fate")
	quit()
