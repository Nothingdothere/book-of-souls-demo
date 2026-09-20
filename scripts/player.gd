extends CharacterBody2D

@export var walk_speed: float = 180.0
@export var gravity: float = 1400.0
@export var left_boundary: float = 155.0
@export var right_boundary: float = INF
@onready var artwork: AnimatedSprite2D = $Artwork
var controls_locked := false
var has_soul_star := false

func award_soul_star() -> void:
	if has_soul_star:
		return
	has_soul_star = true
	var star := Node2D.new()
	star.set_script(preload("res://scripts/soul_star.gd"))
	add_child(star)

# Source-space hip centres and sole baselines. Original PNGs stay intact.
const PIVOTS := [Vector2(554, 1460), Vector2(546, 1437), Vector2(560, 1451), Vector2(575, 1430), Vector2(588, 1455), Vector2(549, 1457), Vector2(555, 1451), Vector2(560, 1444)]
const ART_SCALE := 0.285
const IDLE_PIVOT := Vector2(550, 1479)

func _ready() -> void:
	artwork.animation = "idle"
	artwork.scale = Vector2.ONE * ART_SCALE
	artwork.frame_changed.connect(_align_frame)
	artwork.animation_changed.connect(_align_frame)
	_align_frame()

func _align_frame() -> void:
	var pivot: Vector2 = PIVOTS[artwork.frame] if artwork.animation == &"walk" else IDLE_PIVOT
	var texture := artwork.sprite_frames.get_frame_texture(artwork.animation, artwork.frame)
	var drawing_offset := Vector2(texture.get_width() * 0.5 - pivot.x, texture.get_height() * 0.5 - pivot.y)
	if artwork.flip_h:
		drawing_offset.x = -drawing_offset.x
	artwork.position = drawing_offset * ART_SCALE

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	direction = clampf(direction, -1.0, 1.0)
	if controls_locked:
		direction = 0.0
	velocity.x = direction * walk_speed
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	position.x = clampf(position.x, left_boundary, right_boundary)
	if direction != 0.0:
		# Temporary reflection until separate left-facing drawings exist.
		artwork.flip_h = direction < 0.0
		artwork.play("walk" if absf(velocity.x) > 0.1 else "idle")
	else:
		artwork.play("idle")
	_align_frame()
