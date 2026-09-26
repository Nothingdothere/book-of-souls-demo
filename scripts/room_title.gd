extends CanvasLayer

var shown_titles: Dictionary = {}
var panel: VBoxContainer
var label: Label
var active_tween: Tween

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -60)
	panel.size = Vector2(800, 120)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://assets/fonts/CormorantGaramond.ttf"))
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color("eedbb7"))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.025, 0.95))
	label.add_theme_constant_override("shadow_outline_size", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.modulate.a = 0

func reveal(text: String) -> void:
	if shown_titles.has(text):
		return
	shown_titles[text] = true
	label.text = text
	if active_tween:
		active_tween.kill()
	panel.modulate.a = 0.0
	active_tween = create_tween()
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.8)
	active_tween.tween_interval(2.2)
	active_tween.tween_property(panel, "modulate:a", 0.0, 1.5)
