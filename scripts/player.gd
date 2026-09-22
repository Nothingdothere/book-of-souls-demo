extends CharacterBody2D

@export var walk_speed: float = 180.0
@export var gravity: float = 1400.0
@export var left_boundary: float = 155.0
@export var right_boundary: float = INF
@onready var artwork: AnimatedSprite2D = $Artwork
@onready var contact_shadow: Node2D = $ContactShadow
var controls_locked := false
var has_soul_star := false
var hall_frames: SpriteFrames
var no_cat_frames: SpriteFrames
var without_cat := false
var visual_offset := Vector2.ZERO
var smoke_burst: CPUParticles2D

func award_soul_star() -> void:
	if has_soul_star:
		return
	has_soul_star = true
	var star := Node2D.new()
	star.set_script(preload("res://scripts/soul_star.gd"))
	add_child(star)

# Source-space hip centres and sole baselines. Original PNGs stay intact.
const PIVOTS := [Vector2(554, 1460), Vector2(546, 1437), Vector2(560, 1451), Vector2(575, 1430), Vector2(588, 1455), Vector2(549, 1457), Vector2(555, 1451), Vector2(560, 1444)]
const IDLE_PIVOT := Vector2(550, 1479)
const NO_CAT_IDLE_PIVOT := Vector2(550, 1512)

func _ready() -> void:
	hall_frames = artwork.sprite_frames
	artwork.animation = "idle"
	artwork.frame_changed.connect(_align_frame)
	artwork.animation_changed.connect(_align_frame)
	_align_frame()
	_setup_smoke_burst()

func _setup_smoke_burst() -> void:
	var puff_gradient := Gradient.new()
	puff_gradient.set_color(0, Color(1, 1, 1, 1))
	puff_gradient.set_color(1, Color(1, 1, 1, 0))
	var puff_texture := GradientTexture2D.new()
	puff_texture.gradient = puff_gradient
	puff_texture.fill = GradientTexture2D.FILL_RADIAL
	puff_texture.fill_from = Vector2(0.5, 0.5)
	puff_texture.fill_to = Vector2(1.0, 0.5)
	puff_texture.width = 64
	puff_texture.height = 64
	smoke_burst = CPUParticles2D.new()
	smoke_burst.name = "SmokeBurst"
	smoke_burst.texture = puff_texture
	smoke_burst.emitting = false
	smoke_burst.one_shot = true
	smoke_burst.amount = 28
	smoke_burst.lifetime = 0.6
	smoke_burst.explosiveness = 0.85
	smoke_burst.direction = Vector2.UP
	smoke_burst.spread = 100.0
	smoke_burst.gravity = Vector2(0, -55)
	smoke_burst.initial_velocity_min = 35.0
	smoke_burst.initial_velocity_max = 100.0
	smoke_burst.scale_amount_min = 0.7
	smoke_burst.scale_amount_max = 1.6
	smoke_burst.color = Color(0.04, 0.035, 0.05, 0.85)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.04, 0.035, 0.05, 0.85))
	fade.set_color(1, Color(0.04, 0.035, 0.05, 0.0))
	smoke_burst.color_ramp = fade
	smoke_burst.position = Vector2(0, -150)
	# Global coords: an in-flight puff must not snap to the new spot when
	# _set_location teleports the player mid-transition.
	smoke_burst.local_coords = false
	add_child(smoke_burst)

func dissolve_out(duration := 0.18) -> void:
	smoke_burst.restart()
	smoke_burst.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(artwork, "modulate:a", 0.0, duration)
	tween.tween_property(contact_shadow, "modulate:a", 0.0, duration)
	await tween.finished

func dissolve_in(duration := 0.18) -> void:
	smoke_burst.restart()
	smoke_burst.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(artwork, "modulate:a", 1.0, duration)
	tween.tween_property(contact_shadow, "modulate:a", 1.0, duration)
	await tween.finished

func _align_frame() -> void:
	var pivot: Vector2 = PIVOTS[artwork.frame] if artwork.animation == &"walk" else NO_CAT_IDLE_PIVOT if without_cat else IDLE_PIVOT
	var texture := artwork.sprite_frames.get_frame_texture(artwork.animation, artwork.frame)
	var drawing_offset := Vector2(texture.get_width() * 0.5 - pivot.x, texture.get_height() * 0.5 - pivot.y)
	if artwork.flip_h:
		drawing_offset.x = -drawing_offset.x
	artwork.position = drawing_offset * artwork.scale + visual_offset

func set_without_cat(value: bool) -> void:
	if without_cat == value:
		return
	without_cat = value
	if value and no_cat_frames == null:
		no_cat_frames = SpriteFrames.new()
		for animation_name in [&"idle", &"walk"]:
			no_cat_frames.add_animation(animation_name)
			no_cat_frames.set_animation_speed(animation_name, 4.0 if animation_name == &"idle" else 8.0)
			var frame_numbers := [1, 2, 3, 4, 5, 6, 7, 8] if animation_name == &"idle" else [1, 3, 4, 5, 6, 7, 8, 9]
			for number in frame_numbers:
				var path := "res://assets/character/no_cat/dark_%s_right_%02d.png" % [animation_name, number]
				no_cat_frames.add_frame(animation_name, load(path))
	artwork.sprite_frames = no_cat_frames if value else hall_frames
	artwork.play("idle")
	_align_frame()

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
