extends AnimatedSprite2D

var animation_clock := 0.0
var animation_step := 0
var purr_player: AudioStreamPlayer
var meow_player: AudioStreamPlayer
var meow_elapsed := 0.0
var next_meow := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	play("blink")
	rng.randomize()
	purr_player = AudioStreamPlayer.new()
	purr_player.stream = load("res://assets/audio/sfx/cat_purr.wav")
	purr_player.volume_db = -26.0
	purr_player.finished.connect(func(): if is_visible_in_tree(): purr_player.play())
	add_child(purr_player)
	meow_player = AudioStreamPlayer.new()
	meow_player.stream = load("res://assets/audio/sfx/cat_meow.wav")
	meow_player.volume_db = -16.0
	add_child(meow_player)
	_schedule_meow()

func _schedule_meow() -> void:
	meow_elapsed = 0.0
	next_meow = rng.randf_range(14.0, 28.0)

func _process(delta: float) -> void:
	var visible_now := is_visible_in_tree()
	if visible_now and not purr_player.playing:
		purr_player.play()
	elif not visible_now and purr_player.playing:
		purr_player.stop()
	if not visible_now:
		return
	animation_clock += delta
	if animation_clock >= 4.0:
		animation_clock = 0.0
		animation_step += 1
		play(["wash", "blink", "paw", "blink"][animation_step % 4])
	meow_elapsed += delta
	if meow_elapsed >= next_meow:
		meow_player.play()
		_schedule_meow()
