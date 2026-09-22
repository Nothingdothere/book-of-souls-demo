extends AnimatedSprite2D

var animation_clock := 0.0
var animation_step := 0

func _ready() -> void:
	play("blink")

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	animation_clock += delta
	if animation_clock >= 4.0:
		animation_clock = 0.0
		animation_step += 1
		play(["wash", "blink", "paw", "blink"][animation_step % 4])
