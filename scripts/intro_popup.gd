extends CanvasLayer

signal dismissed

const MARKER_PATH := "user://intro_seen.marker"
const MESSAGE := "Игра находится на ранней стадии разработки.\nВсё, что вы увидите сейчас, может измениться: визуальный стиль, диалоги, механики, интерфейс и отдельные элементы истории.\nЭта версия создана, чтобы показать атмосферу, основные идеи и направление проекта.\n\nСпасибо, что заглянули сюда так рано."

var root_control: Control
var dim: ColorRect
var stage: Control
var content: Control
var art_layer: Control
var appear_sfx: AudioStreamPlayer
var handwriting: Font
var stage_base_y := 0.0
var float_time := 0.0
var dismissing := false

func _ready() -> void:
	layer = 100
	if OS.has_feature("web"):
		handwriting = preload("res://assets/fonts/Caveat.ttf")
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Segoe Script", "Gabriola"])
		handwriting = system_font
	_build_interface()
	appear_sfx.play()

func _build_interface() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(stage)
	content = Control.new()
	content.size = Vector2(1280, 720)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(content)
	# Dark stands on his own, non-floating layer: only the parchment/text
	# should bob, and his art runs well past the bottom of the reference
	# frame (his source image crops at the thigh — better off-screen than
	# visibly cut off) so it must not ride along with the float offset
	# applied to `stage` below, or the crop line would bob in and out too.
	art_layer = Control.new()
	art_layer.size = Vector2(1280, 720)
	art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(art_layer)

	var parchment := TextureRect.new()
	parchment.texture = preload("res://assets/ui/intro/popup_parchment.png")
	parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parchment.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	parchment.position = Vector2(180, 110)
	parchment.size = Vector2(760, 507)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(parchment)

	var dark_art := TextureRect.new()
	dark_art.texture = preload("res://assets/ui/intro/dark_intro.png")
	dark_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dark_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	dark_art.position = Vector2(760, 130)
	dark_art.size = Vector2(430, 645)
	dark_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_layer.add_child(dark_art)

	var message := Label.new()
	message.text = MESSAGE
	message.position = Vector2(280, 205)
	message.size = Vector2(340, 305)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", handwriting)
	message.add_theme_font_size_override("font_size", 21)
	message.add_theme_color_override("font_color", Color("34271d"))
	message.add_theme_constant_override("line_spacing", 3)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(message)

	var start_button := Button.new()
	start_button.text = "Начать"
	start_button.position = Vector2(370, 520)
	start_button.size = Vector2(170, 45)
	start_button.flat = true
	start_button.add_theme_font_override("font", handwriting)
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.add_theme_color_override("font_color", Color("34271d"))
	start_button.add_theme_color_override("font_hover_color", Color("6b2f1a"))
	start_button.pressed.connect(_on_start_pressed)
	content.add_child(start_button)

	appear_sfx = AudioStreamPlayer.new()
	appear_sfx.stream = load("res://assets/audio/sfx/book_flip.ogg")
	add_child(appear_sfx)

	get_viewport().size_changed.connect(_layout)
	_layout()
	stage_base_y = stage.position.y

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = Vector2((viewport_size.x - 1280.0 * factor) * 0.5, (viewport_size.y - 720.0 * factor) * 0.5)
	stage_base_y = stage.position.y
	# art_layer sits outside stage (so it doesn't float), but still needs the
	# same viewport-fit transform or Dark won't line up with the parchment.
	art_layer.scale = stage.scale
	art_layer.position = stage.position

func _process(delta: float) -> void:
	if dismissing:
		return
	float_time += delta
	stage.position.y = stage_base_y + sin(float_time * 1.1) * 7.0

func _on_start_pressed() -> void:
	if dismissing:
		return
	dismissing = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(content, "modulate:a", 0.0, 0.6)
	tween.tween_property(art_layer, "modulate:a", 0.0, 0.6)
	tween.tween_property(dim, "color:a", 0.0, 0.6)
	tween.chain().tween_callback(_finish)

func _finish() -> void:
	var marker := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if marker:
		marker.store_string("1")
	dismissed.emit()
	queue_free()
