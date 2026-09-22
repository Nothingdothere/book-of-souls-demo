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
var smoke_time := -1.0
const SMOKE_DURATION := 0.9
const SMOKE_POINTS := 60
var footstep_player: AudioStreamPlayer
var indoor_step: AudioStream
var outdoor_step: AudioStream
var outdoor_footsteps := false
var footstep_rng := RandomNumberGenerator.new()
# Foot-contact poses in the 8-frame walk cycle (see PIVOTS below).
const FOOTSTEP_FRAMES := [0, 4]

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
	artwork.frame_changed.connect(_on_walk_frame)
	artwork.animation_changed.connect(_align_frame)
	_align_frame()
	footstep_rng.randomize()
	indoor_step = load("res://assets/audio/sfx/footstep_indoor.ogg")
	outdoor_step = load("res://assets/audio/sfx/footstep_outdoor.ogg")
	footstep_player = AudioStreamPlayer.new()
	add_child(footstep_player)

func _process(delta: float) -> void:
	if smoke_time < 0.0:
		return
	smoke_time += delta
	if smoke_time >= SMOKE_DURATION:
		smoke_time = -1.0
	queue_redraw()

func _draw() -> void:
	if smoke_time < 0.0 or smoke_time >= SMOKE_DURATION:
		return
	# Same layered soft-circle plume as Lina's departure mist (lina.gd),
	# just tall and wide enough to swallow Dark's whole silhouette instead
	# of drifting off a single point. Centered on visual_offset and scaled
	# by artwork.scale so it lines up with the sprite in every location
	# (hall/cafe/street each use a different preview offset and scale).
	var opacity := sin(PI * smoke_time / SMOKE_DURATION) * 0.7
	var scale_factor: float = artwork.scale.y / 0.285
	for i in range(SMOKE_POINTS):
		var phase := float(i) * 2.39996
		var height_t := float(i) / SMOKE_POINTS
		var point := visual_offset + Vector2(sin(phase + smoke_time * 3.0) * (26 + i % 6 * 12), -14 - height_t * 400.0 - smoke_time * 60.0) * scale_factor
		var tint := Color(0.025, 0.018, 0.035, opacity)
		for ring in range(8, 0, -1):
			var soft_tint := tint
			soft_tint.a *= 0.16
			draw_circle(point, (16 + i % 6) * float(ring) / 8.0 * scale_factor, soft_tint)

func dissolve_out(duration := SMOKE_DURATION * 0.7) -> void:
	smoke_time = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(artwork, "modulate:a", 0.0, duration)
	tween.tween_property(contact_shadow, "modulate:a", 0.0, duration)
	await tween.finished

func dissolve_in(duration := SMOKE_DURATION * 0.7) -> void:
	smoke_time = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(artwork, "modulate:a", 1.0, duration)
	tween.tween_property(contact_shadow, "modulate:a", 1.0, duration)
	await tween.finished

func _on_walk_frame() -> void:
	if artwork.animation != &"walk" or artwork.frame not in FOOTSTEP_FRAMES:
		return
	footstep_player.stream = outdoor_step if outdoor_footsteps else indoor_step
	# One sample per surface reads as a machine-gun loop if played identically
	# every step; a per-step pitch/volume jitter (plus a small offset between
	# the two feet) fakes the variation a pair of real recordings would give.
	var foot_offset := 0.0 if artwork.frame == FOOTSTEP_FRAMES[0] else 0.05
	footstep_player.pitch_scale = 1.0 + foot_offset + footstep_rng.randf_range(-0.08, 0.08)
	# Kept well under the music bus (-20dB) per feedback that steps still
	# read louder than the score.
	footstep_player.volume_db = footstep_rng.randf_range(-34.0, -30.0)
	footstep_player.play()

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
