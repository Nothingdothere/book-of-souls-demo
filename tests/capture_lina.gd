extends SceneTree

var output := "res://../lina_previews/"
var overflow := 0

func _initialize() -> void:
	call_deferred("capture")

func shot(file_name: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + file_name + ".png")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene._topic_finished("kas", "topic_6")
	scene.player.position.x = 2400
	await create_timer(1.3).timeout
	await shot("01_title")
	scene.player.position.x = 2950
	await create_timer(4.0).timeout
	await shot("02_room")
	scene.try_talk()
	var d = scene.dialogue
	d.advance()
	d.advance()
	d.advance()
	await shot("03_lina")
	while not d.choosing:
		d.advance()
	await shot("04_questions")
	for topic in d.data["topics"]:
		d.visited[topic["id"]] = true
	d._show_choices(1)
	await shot("05_unlocked_questions")
	d._show_verdict()
	d.choose_verdict("rebirth")
	while d.active:
		d.advance()
	await create_timer(2.0).timeout
	await shot("06_star")
	d.root_control.show()
	var entries: Array = d.data["intro"].duplicate()
	for topic in d.data["topics"]:
		entries.append_array(topic["lines"])
	for ending in d.data["endings"].values():
		entries.append_array(ending)
	for entry in entries:
		d.lines = [entry]
		d.line_index = 0
		d._show_line()
		for page in d.pages:
			d.body.text = page
			d.body.visible_characters = -1
			await process_frame
			if d.body.get_content_height() > d.body.size.y:
				overflow += 1
				print("OVERFLOW ", page)
	print("LINA_LAYOUT_OVERFLOWS ", overflow, " ENTRIES ", entries.size())
	quit(1 if overflow else 0)
