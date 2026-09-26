extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var b = scene.book
	var d = scene.dialogue
	check(not b.arbiter_known and b.page_count() == 3, "Arbiter revealed before warning")
	scene._set_location("other_side", scene.other_side.get_node("PlayerSpawn").position)
	scene.player.velocity.x = 180
	scene._update_wastes_warning(15.0)
	check(d.active and d.conversation_id == "other_side_warning" and b.arbiter_known, "Warning did not unlock Arbiter dossier")
	check(b.page_count() == 4 and not b.lina_known and not b.diana_known, "Arbiter unlocked unrelated dossiers")
	check(scene.book_has_new_entry, "New dossier has no book alert")
	d.advance()
	d.advance()
	b.unlocked = true
	b.open()
	b.page = b.page_count() - 1
	b._show_page()
	await process_frame
	check(b.heading.text == "Арбитр" and b.classification.text == "Тип: Верховная сущность", "Arbiter page has wrong name/type")
	check(b.photo.texture.resource_path.ends_with("arbiter.png"), "Arbiter portrait missing")
	check("Арбитр существует дольше самой Вселенной." in b.body.text and "было ли у него когда-либо начало." in b.body.text, "Dossier text truncated")
	check(b.body.get_content_height() <= b.body.size.y, "Arbiter dossier overflows desktop page")
	b.body.add_theme_font_override("normal_font", preload("res://assets/fonts/Caveat.ttf"))
	b.body.add_theme_font_size_override("normal_font_size", 29)
	b.body.add_theme_constant_override("line_separation", 0)
	await process_frame
	check(b.body.get_content_height() <= b.body.size.y, "Arbiter dossier overflows browser page")
	b.close()
	check(not scene.book_has_new_entry, "Reading did not clear book alert")
	scene._set_location("hall", Vector2(687, 771))
	scene._set_location("other_side", scene.other_side.get_node("PlayerSpawn").position)
	scene.player.velocity.x = 180
	scene._update_wastes_warning(15.0)
	check(b.page_count() == 4 and not scene.book_has_new_entry, "Repeated warning duplicates dossier/alert")
	d.close()
	b.lina_known = true
	b.diana_known = true
	check(b.page_count() == 6 and b._available_entries().back()["id"] == "arbiter", "Arbiter disappeared as other dossiers unlocked")
	if failures.is_empty():
		print("PASS: warning-gated Arbiter dossier, portrait/exact text, independent unlocks, desktop/browser text fit and deduplicated alert")
	quit(0 if failures.is_empty() else 1)
