extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var control: Control = scene.get_node("Interface/Controls")
	var font := control.get_theme_font("font")
	print("PROJECT_FONT ", font.resource_path)
	var failures := 0
	for character in "АБВЯабвя0123456789-—·:()":
		if not font.has_char(character.unicode_at(0)):
			print("MISSING_GLYPH ", character)
			failures += 1
	if not font.resource_path.ends_with("NotoSans.ttf"):
		failures += 1
	if "←" in control.text or "→" in control.text:
		print("UNSUPPORTED_ARROW_IN_HUD")
		failures += 1
	for pair in [
		["Caveat", load("res://assets/fonts/Caveat.ttf")],
		["Cormorant", load("res://assets/fonts/CormorantGaramond.ttf")]
	]:
		for character in "АЯая—«»…":
			if not pair[1].has_char(character.unicode_at(0)):
				print("MISSING_GLYPH ", pair[0], " ", character)
				failures += 1
	if failures == 0:
		print("PASS: embedded UI font covers Russian text and punctuation")
	quit(0 if failures == 0 else 1)
