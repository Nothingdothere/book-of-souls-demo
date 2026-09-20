extends SceneTree

var dialogue
var output := "res://../dialogue_previews/"
var overflow_count := 0

func _initialize() -> void:
	call_deferred("capture")

func screenshot(file_name: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output + file_name + ".png")
	print("CAPTURE ", file_name, " ", result)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	dialogue = scene.get_node("Dialogue")
	scene.get_node("Player").position.x = scene.get_node("Kas").position.x + 150
	for frame in range(30):
		await process_frame
	await screenshot("00_library_kas")
	scene.try_talk()
	dialogue.advance()
	await screenshot("01_narration")
	dialogue.advance()
	dialogue.advance()
	await screenshot("02_kas")
	dialogue.advance()
	dialogue.advance()
	await screenshot("03_dark")
	while not dialogue.choosing:
		dialogue.advance()
	await screenshot("04_topics")
	var all_lines: Array = dialogue.data["intro"].duplicate()
	for topic in dialogue.data["topics"]:
		all_lines.append_array(topic["lines"])
	for entry in all_lines:
		dialogue.lines = [entry]
		dialogue.line_index = 0
		dialogue._show_line()
		for page in dialogue.pages:
			dialogue.body.text = page
			dialogue.body.visible_characters = -1
			await process_frame
			if dialogue.body.get_content_height() > dialogue.body.size.y:
				overflow_count += 1
				print("OVERFLOW ", dialogue.body.get_content_height(), " ", page)
	print("LAYOUT_OVERFLOWS ", overflow_count)
	quit(1 if overflow_count > 0 else 0)
