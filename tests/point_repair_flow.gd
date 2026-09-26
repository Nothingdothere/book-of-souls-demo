extends SceneTree

var failures: Array[String] = []
var assignment_requests := 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func finish_lines(d: Node) -> void:
	var guard := 0
	while d.active and guard < 100:
		d.advance()
		guard += 1
	check(guard < 100, "Dialogue stuck")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var d = scene.dialogue
	d.followup_completed = true
	scene.walk_quest_active = true
	scene.next_assignment_requested.connect(func(): assignment_requests += 1)
	scene._set_location("street", Vector2(1300, 771))
	d.start("diana")
	d.close()
	check(not scene.diana_met, "Interrupted Diana encounter unlocked Point quest")
	d.start("diana")
	finish_lines(d)
	check(scene.diana_met and "(0/5)" in scene.quest_label.text, "Point quest/counter missing after Diana")
	scene._set_location("cafe", Vector2(1080, 771))
	await process_frame
	check(d.active and d.conversation_id == "point_inspection" and d.current_speaker == "dark", "Point entry did not show Dark's introduction")
	check(scene.hotspots.all(func(h): return not h.input_pickable), "Hotspots available before introductory window closed")
	finish_lines(d)
	check(scene.hotspots.all(func(h): return h.marker_enabled and h.input_pickable), "Five hotspots missing after intro")
	var click := InputEventScreenTouch.new()
	click.pressed = true
	scene.hotspots[0]._on_input_event(root, click, 0)
	check(scene.point_inspected.size() == 1 and "(1/5)" in scene.quest_label.text, "First click did not update progress")
	finish_lines(d)
	scene.hotspots[0]._on_input_event(root, click, 0)
	finish_lines(d)
	check(scene.point_inspected.size() == 1, "Repeated click increased progress")
	scene._set_location("street", Vector2(1300, 771))
	scene._set_location("cafe", Vector2(1080, 771))
	await process_frame
	check(not d.active and scene.point_inspected.size() == 1, "Re-entry reset progress or repeated introductory window")
	for i in range(1, 5):
		scene.hotspots[i]._on_input_event(root, click, 0)
		check(scene.point_inspected.size() == i + 1, "Unique hotspot did not update progress")
		finish_lines(d)
		await process_frame
	check(d.active and d.conversation_id == "point_repair" and "(5/5)" in scene.quest_label.text, "Fifth inspection did not open repair dialogue")
	d.close()
	check(not scene.point_repair_planned, "Aborted repair conversation advanced quest")
	scene.hotspots[0]._on_input_event(root, click, 0)
	check(d.active and d.conversation_id == "point_repair", "Repair conversation cannot be resumed")
	finish_lines(d)
	check(scene.point_repair_planned and scene.quest_label.text == "Задание: вернуться к Касу", "Repair conversation did not replace counter with return-to-Kas objective")
	check(scene.hotspots.all(func(h): return not h.input_pickable), "Inspection hotspots still enabled while awaiting next quest")
	var old_texture: Texture2D = scene.coffee_interior.get_node("CounterAndShelves").texture
	scene._set_location("hall", Vector2(687, 771))
	scene._set_location("cafe", Vector2(1080, 771))
	await process_frame
	check(not scene.point_repaired and scene.coffee_interior.get_node("CounterAndShelves").texture == old_texture, "Cafe repaired simply by travelling away and back")
	scene._set_location("hall", Vector2(350, 771))
	scene._try_point_next_assignment()
	check(assignment_requests == 1 and d.active and d.conversation_id == "kas_wastes", "Kas did not automatically give the wastes assignment after Point inspection/repair conversation")
	check(not scene.point_next_assignment_started and not scene.wastes_quest_unlocked, "Assignment unlocked before Kas finished speaking")
	d.close()
	scene._try_point_next_assignment()
	check(not d.active and not scene.wastes_quest_unlocked and scene.quest_label.text == "Задание: вернуться к Касу", "Aborting Kas dialogue skipped quest or immediately reopened it")
	scene.try_talk()
	check(d.active and d.conversation_id == "kas_wastes", "Interrupted assignment cannot be resumed with interact")
	finish_lines(d)
	check(scene.point_next_assignment_started and scene.wastes_quest_unlocked and scene.travel_button.text == "На Ту-сторону", "Completed Kas conversation did not unlock normal travel to Ta-side")
	check(scene.quest_label.text == "Задание: осмотреть переход на Той-стороне", "Wastes mission objective missing")
	check(not scene.point_repair_ready, "Finishing new quest's opening conversation prematurely repaired the Point")
	await scene.travel()
	check(scene.location == "other_side" and not scene.wastes_quest_inspected, "Travel did not enter Ta-side or completed inspection too early")
	scene.player.velocity.x = 180.0
	scene._update_wastes_warning(15.0)
	check(d.active and d.conversation_id == "other_side_warning" and scene.book.arbiter_known, "Wastes warning/Arbiter dossier missing")
	check(scene.wastes_quest_inspected and scene.quest_label.text == "Задание: вернуться к Касу" and not scene.point_repair_ready, "Arbiter warning did not change objective to return to Kas")
	finish_lines(d)
	await scene.travel()
	for frame in range(3):
		await process_frame
	check(scene.location == "hall" and d.active and d.conversation_id == "kas_wastes_return", "Returning from wastes did not start Kas's Point reminder")
	d.close()
	scene._try_wastes_return_dialogue()
	check(not d.active and not scene.wastes_quest_completed and not scene.point_repair_ready, "Interrupted return dialogue completed repair or immediately reopened")
	scene.try_talk()
	check(d.active and d.conversation_id == "kas_wastes_return", "Return reminder cannot be resumed")
	finish_lines(d)
	check(scene.wastes_quest_completed and scene.quest_label.text == "Задание: вернуться в Точку", "Kas reminder did not send Dark to Point")
	check(scene.point_repair_ready and not scene.point_repaired, "Quest completion did not queue repair for return")
	await scene.travel()
	await process_frame
	check(scene.location == "cafe", "Travel after Kas reminder did not return to Point")
	check(scene.point_repaired and scene.coffee_interior.get_node("CounterAndShelves").texture.resource_path.ends_with("cafe_repaired.png"), "Return after quest did not switch interior")
	check(d.active and d.conversation_id == "point_repaired" and d.current_speaker == "dark", "Repaired Point did not open Dark's praise")
	check(not scene.transitioning and is_equal_approx(scene.player.artwork.modulate.a, 1.0), "Praise began before arrival animation finished")
	check(scene.hotspots.all(func(h): return not h.input_pickable), "Hotspots clickable during praise")
	d.close()
	check(not scene.point_repair_praised, "Interrupted praise counted as completed")
	scene._set_location("street", Vector2(1300, 771))
	scene._set_location("cafe", Vector2(1080, 771))
	scene._try_point_entry_dialogue()
	check(d.active and d.conversation_id == "point_repaired", "Interrupted praise did not resume on re-entry")
	d.advance()
	d.advance()
	check(d.current_speaker == "point" and not d.portrait.visible and "довольное урчание" in d.body.text, "Point's pleased response/hidden portrait missing")
	finish_lines(d)
	check(scene.point_repair_praised, "Completed praise was not remembered")
	scene._set_location("street", Vector2(1300, 771))
	scene._set_location("cafe", Vector2(1080, 771))
	for frame in range(3):
		await process_frame
	check(not d.active, "Completed praise repeated on another visit")
	check(not scene.coffee_interior.get_node("HotspotWall").visible and not scene.coffee_interior.get_node("HotspotWall").input_pickable, "Repaired wall remains clickable")
	check(scene.hotspots.filter(func(h): return h.input_pickable and h.marker_enabled).size() == 4, "Repaired cafe does not have exactly four hotspots")
	scene._on_hotspot_clicked("coffee_hotspot_wall")
	check(not d.active, "Removed wall hotspot still opens a conversation")
	scene.hotspots[0]._on_input_event(root, click, 0)
	check(d.active and d.conversation_id == "coffee_hotspot_machine", "Remaining hotspots stopped working after repair")
	finish_lines(d)
	check(not "(5/5)" in scene.quest_label.text and assignment_requests == 1, "Old counter or repeated new-quest request remains")
	if failures.is_empty():
		print("PASS: five unique touch clicks, repair dialogue/retry, Kas wastes assignment/retry, normal travel, warning/Arbiter unlock, return to Kas/retry, repaired Point and four remaining hotspots")
	quit(0 if failures.is_empty() else 1)
