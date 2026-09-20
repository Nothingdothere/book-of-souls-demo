extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func finish_lines(d) -> void:
	var guard := 0
	while d.active and not d.choosing and guard < 400:
		d.advance()
		guard += 1
	check(guard < 400, "Dialogue stuck")

func verify() -> void:
	for outcome in ["rebirth_understood", "rebirth_rushed", "oblivion"]:
		var scene = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		var d = scene.dialogue
		var p = scene.player
		d.start()
		finish_lines(d)
		d.choose_topic("topic_6")
		finish_lines(d)
		d.close()
		p.position.x = 2950
		await physics_frame
		await process_frame
		check(scene.room_title.shown, "Reading room title not triggered")
		scene.try_talk()
		check(d.active and d.conversation_id == "lina" and p.controls_locked, "Lina interaction failed")
		check(not d.portrait.visible, "Narration has portrait")
		d.advance()
		d.advance()
		check(d.current_speaker == "lina" and d.portrait.position.x > 640 and not d.portrait.flip_h, "Lina portrait position incorrect")
		finish_lines(d)
		check(d._available_topics().size() == 4, "Initial topics incorrect")
		d.choose_topic("return")
		check(d.choosing, "Locked topic accessible")
		if outcome == "rebirth_understood":
			for topic in ["name", "last_memory", "wrists", "life", "reluctance", "death_wish", "alone", "kris", "return"]:
				d.choose_topic(topic)
				check(not d.choosing, "Topic failed: " + topic)
				finish_lines(d)
				check(d.visited.has(topic), "Topic not remembered: " + topic)
				check(d.choices.get_child_count() <= 8, "Choices overflow")
			d.close()
			d.start("kas")
			check(d.visited.size() == 1 and d.visited.has("topic_6"), "Lina history leaked to Kas")
			d.close()
			d.start("lina")
			check(d.visited.size() == 9, "Lina progress lost")
			finish_lines(d)
		d._show_verdict()
		d.choose_verdict("oblivion" if outcome == "oblivion" else "rebirth")
		check(d.pending_outcome == outcome, "Wrong outcome selected")
		finish_lines(d)
		await process_frame
		check(d.lina_resolved and scene.lina.resolved and not p.controls_locked, "Outcome did not finish")
		check(scene.lina.collision.disabled, "Departed soul still blocks path")
		check(p.has_soul_star == (outcome == "rebirth_understood"), "Wrong star award")
		d.start("lina")
		check(not d.active, "Resolved soul reopened")
		scene.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: Lina gating, all nine branches, history separation, portraits, three endings, star and removal")
	quit(0 if failures.is_empty() else 1)
