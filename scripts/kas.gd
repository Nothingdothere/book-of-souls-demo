extends Node2D

@onready var artwork: AnimatedSprite2D = $Artwork
@onready var prompt: Label = $Prompt
const SCALE := 0.285
const SIDE_PIVOT := Vector2(532, 1472)
const FRONT_PIVOT := Vector2(512, 1492)

func _ready() -> void:
	artwork.frame_changed.connect(_align_frame)
	artwork.animation_changed.connect(_align_frame)
	set_conversing(false)

func set_conversing(value: bool, interlocutor_x: float = 0.0) -> void:
	artwork.flip_h = value and interlocutor_x < global_position.x
	artwork.play("side" if value else "front")
	prompt.visible = false
	_align_frame()

func _align_frame() -> void:
	var pivot := FRONT_PIVOT if artwork.animation == &"front" else SIDE_PIVOT
	var image := artwork.sprite_frames.get_frame_texture(artwork.animation, artwork.frame)
	var drawing_offset := (Vector2(image.get_size()) * 0.5 - pivot) * SCALE
	if artwork.flip_h:
		drawing_offset.x = -drawing_offset.x
	artwork.position = drawing_offset
