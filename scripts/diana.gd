extends Node2D

@onready var artwork: AnimatedSprite2D = $Artwork
@onready var prompt: Label = $Prompt

# Frame indices (0-based) into the "idle" SpriteFrames animation.
# 1-6.png: cigarette hand up, free hand resting down, with tiny natural
# variation between them. 7-8.png: free hand moved up onto her hip.
const DOWN_POSE_FRAMES := [0, 1, 2, 3, 4, 5]
const UP_POSE_FRAME := 7
# Frames played in order to move from the down pose to the hip pose (and
# reversed to move back) — extend this if more in-between frames get added.
const RAISE_FRAMES := [5, 6, 7]

const DOWN_HOLD_TIME := 4.0
const UP_HOLD_TIME := 2.5
const DOWN_FIDGET_TIME := 1.3
const TRANSITION_STEP_TIME := 0.12

enum State { HOLD_DOWN, RAISING, HOLD_UP, LOWERING }

var state := State.HOLD_DOWN
var state_timer := DOWN_HOLD_TIME
var fidget_timer := 0.0
var fidget_index := 0
var transition_step := 0
var transition_frames: Array

func _ready() -> void:
	artwork.stop()
	artwork.frame = DOWN_POSE_FRAMES[0]
	_position_prompt()

func _position_prompt() -> void:
	# Artwork gets dragged around independently of this node's own origin
	# (see the CollisionShape2D comment in library.gd) — anchor the prompt
	# to wherever she actually ends up instead of a fixed offset.
	var texture := artwork.sprite_frames.get_frame_texture(&"idle", 0)
	var top_y: float = artwork.position.y - texture.get_height() * 0.5 * artwork.scale.y
	prompt.position = Vector2(artwork.position.x - prompt.size.x * 0.5, top_y - 40.0 - prompt.size.y)

func _process(delta: float) -> void:
	state_timer -= delta
	match state:
		State.HOLD_DOWN:
			fidget_timer += delta
			if fidget_timer >= DOWN_FIDGET_TIME:
				fidget_timer = 0.0
				fidget_index = (fidget_index + 1) % DOWN_POSE_FRAMES.size()
				artwork.frame = DOWN_POSE_FRAMES[fidget_index]
			if state_timer <= 0.0:
				_start_transition(State.RAISING, RAISE_FRAMES)
		State.RAISING:
			if state_timer <= 0.0:
				_advance_transition(State.HOLD_UP, UP_POSE_FRAME, UP_HOLD_TIME)
		State.HOLD_UP:
			if state_timer <= 0.0:
				var lower_frames := RAISE_FRAMES.duplicate()
				lower_frames.reverse()
				_start_transition(State.LOWERING, lower_frames)
		State.LOWERING:
			if state_timer <= 0.0:
				_advance_transition(State.HOLD_DOWN, DOWN_POSE_FRAMES[0], DOWN_HOLD_TIME)

func _start_transition(next_state: State, frames: Array) -> void:
	state = next_state
	transition_frames = frames
	transition_step = 0
	artwork.frame = transition_frames[0]
	state_timer = TRANSITION_STEP_TIME

func _advance_transition(hold_state: State, hold_frame: int, hold_time: float) -> void:
	transition_step += 1
	if transition_step >= transition_frames.size():
		state = hold_state
		artwork.frame = hold_frame
		state_timer = hold_time
		fidget_timer = 0.0
		fidget_index = 0
	else:
		artwork.frame = transition_frames[transition_step]
		state_timer = TRANSITION_STEP_TIME
