extends CanvasLayer

signal dismissed

const MARKER_PATH := "user://intro_seen.marker"
const MESSAGE := "Игра находится на ранней стадии разработки.\nВсё, что вы увидите сейчас, может измениться: визуальный стиль, диалоги, механики, интерфейс и отдельные элементы истории.\nЭта версия создана, чтобы показать атмосферу, основные идеи и направление проекта.\n\nСпасибо, что заглянули сюда так рано."

var root_control: Control
var dim: ColorRect
var stage: Control
var content: Control
var sparkles: CPUParticles2D
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
	# A separate container for the popup art/text: fading this out on dismiss
	# (rather than the whole stage) leaves the sparkle burst, added straight
	# to stage below, unaffected so it can linger after the popup is gone.
	content = Control.new()
	content.size = Vector2(1280, 720)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(content)

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
	dark_art.position = Vector2(690, 30)
	dark_art.size = Vector2(320, 480)
	dark_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(dark_art)

	var message := Label.new()
	message.text = MESSAGE
	message.position = Vector2(300, 190)
	message.size = Vector2(355, 350)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", handwriting)
	message.add_theme_font_size_override("font_size", 23)
	message.add_theme_color_override("font_color", Color("34271d"))
	message.add_theme_constant_override("line_spacing", 3)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(message)

	var start_button := Button.new()
	start_button.text = "Начать"
	start_button.position = Vector2(390, 550)
	start_button.size = Vector2(170, 56)
	start_button.flat = true
	start_button.add_theme_font_override("font", handwriting)
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.add_theme_color_override("font_color", Color("34271d"))
	start_button.add_theme_color_override("font_hover_color", Color("6b2f1a"))
	start_button.pressed.connect(_on_start_pressed)
	content.add_child(start_button)

	sparkles = CPUParticles2D.new()
	sparkles.position = Vector2(565, 360)
	sparkles.emitting = false
	sparkles.one_shot = true
	sparkles.amount = 200
	sparkles.lifetime = 1.1
	sparkles.explosiveness = 0.75
	sparkles.direction = Vector2.UP
	sparkles.spread = 180.0
	sparkles.gravity = Vector2(0, 40)
	sparkles.initial_velocity_min = 30.0
	sparkles.initial_velocity_max = 160.0
	sparkles.scale_amount_min = 0.15
	sparkles.scale_amount_max = 0.4
	sparkles.texture = _sparkle_texture()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	ramp.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	sparkles.color_ramp = ramp
	stage.add_child(sparkles)

	appear_sfx = AudioStreamPlayer.new()
	appear_sfx.stream = load("res://assets/audio/sfx/book_flip.ogg")
	add_child(appear_sfx)

	get_viewport().size_changed.connect(_layout)
	_layout()
	stage_base_y = stage.position.y

func _sparkle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 16
	texture.height = 16
	return texture

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	stage.scale = Vector2.ONE * factor
	stage.position = Vector2((viewport_size.x - 1280.0 * factor) * 0.5, (viewport_size.y - 720.0 * factor) * 0.5)
	stage_base_y = stage.position.y

func _process(delta: float) -> void:
	if dismissing:
		return
	float_time += delta
	stage.position.y = stage_base_y + sin(float_time * 1.1) * 7.0

func _on_start_pressed() -> void:
	if dismissing:
		return
	dismissing = true
	sparkles.restart()
	sparkles.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(content, "modulate:a", 0.0, 0.7)
	tween.tween_property(dim, "color:a", 0.0, 0.7)
	# Let the sparkle burst (1.1s lifetime) finish playing before freeing
	# this whole node — otherwise it gets cut off right as the fade ends.
	tween.chain().tween_interval(0.4)
	tween.chain().tween_callback(_finish)

func _finish() -> void:
	var marker := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if marker:
		marker.store_string("1")
	dismissed.emit()
	queue_free()
