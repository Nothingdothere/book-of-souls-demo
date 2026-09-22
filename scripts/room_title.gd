extends CanvasLayer

var shown := false
var panel: VBoxContainer

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -95)
	panel.size = Vector2(800, 190)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var font: Font
	if OS.has_feature("web"):
		font = preload("res://assets/fonts/CormorantGaramond.ttf")
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
		font = system_font
	for text in ["Читальный зал", "ПЕРВАЯ ДУША — ЛИНА"]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 46 if panel.get_child_count() == 0 else 21)
		label.add_theme_color_override("font_color", Color("eedbb7"))
		label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.025, 0.95))
		label.add_theme_constant_override("shadow_outline_size", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
	panel.modulate.a = 0

func reveal() -> void:
	if shown:
		return
	shown = true
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "modulate:a", 0.0, 1.5)
