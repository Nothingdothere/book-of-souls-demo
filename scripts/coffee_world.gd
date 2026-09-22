extends Node2D

const CAFE_WIDTH := 1672.0
const STREET_WIDTH := 2700.0
const ART_RISE := -80.0

var interior: Node2D
var street: Node2D
var cat: AnimatedSprite2D
var zone := "cafe"
var cat_clock := 0.0
var cat_step := 0

func _ready() -> void:
	interior = Node2D.new()
	interior.name = "Interior"
	add_child(interior)
	street = Node2D.new()
	street.name = "Street"
	add_child(street)
	_background(interior, Color("211c1b"), CAFE_WIDTH)
	_art(interior, "cafe_back", Vector2(0, ART_RISE), Vector2.ONE, -12)
	_art(interior, "cafe_floor", Vector2(0, ART_RISE), Vector2.ONE, -9)
	_art(interior, "cafe_midground", Vector2(0, ART_RISE), Vector2.ONE, -4)
	_art(interior, "cafe_foreground", Vector2(0, ART_RISE), Vector2.ONE, 5)
	_make_cat()
	_background(street, Color("10141c"), STREET_WIDTH)
	_art(street, "street_parallax", Vector2(0, ART_RISE), Vector2(1.62, 1), -15)
	_art(street, "street_far_buildings", Vector2(0, ART_RISE), Vector2(1.42, 1.14), -13)
	_art(street, "street_more_buildings", Vector2(0, ART_RISE), Vector2.ONE, -10)
	_art(street, "street_back", Vector2(770, ART_RISE), Vector2.ONE, -8)
	_art(street, "street_ground", Vector2(0, 110), Vector2(1.62, 1), -5)
	_art(street, "cafe_exterior", Vector2(1750, 105), Vector2.ONE * 0.65, -3)
	_art(street, "street_foreground", Vector2(0, ART_RISE), Vector2(1.42, 1.14), 5)
	set_zone("cafe")
	hide()

func _background(parent: Node2D, color: Color, width: float) -> void:
	var shape := Polygon2D.new()
	shape.name = "Backdrop"
	shape.z_index = -20
	shape.color = color
	shape.polygon = PackedVector2Array([Vector2(0, -200), Vector2(width, -200), Vector2(width, 1100), Vector2(0, 1100)])
	parent.add_child(shape)

func _art(parent: Node2D, stem: String, at: Vector2, scale_by: Vector2, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = stem.to_pascal_case()
	sprite.texture = load("res://assets/coffee/%s.png" % stem)
	sprite.centered = false
	sprite.position = at
	sprite.scale = scale_by
	sprite.z_index = depth
	parent.add_child(sprite)
	return sprite

func _make_cat() -> void:
	var frames := SpriteFrames.new()
	for animation_name in ["blink", "wash", "paw"]:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 2.4 if animation_name == "blink" else 3.0)
		for number in range(1, 5 if animation_name != "paw" else 6):
			frames.add_frame(animation_name, load("res://assets/cat/%s/%02d.png" % [animation_name, number]))
	cat = AnimatedSprite2D.new()
	cat.name = "CatOnCounter"
	cat.sprite_frames = frames
	cat.position = Vector2(1350, 424)
	cat.scale = Vector2.ONE * 0.42
	cat.z_index = -2
	interior.add_child(cat)
	cat.play("blink")

func set_zone(value: String) -> void:
	zone = value
	interior.visible = value == "cafe"
	street.visible = value == "street"
	cat_clock = 0.0
	if value == "cafe":
		cat.play("blink")
	else:
		cat.stop()

func _process(delta: float) -> void:
	if not visible or zone != "cafe":
		return
	cat_clock += delta
	if cat_clock >= 4.0:
		cat_clock = 0.0
		cat_step += 1
		cat.play(["wash", "blink", "paw", "blink"][cat_step % 4])
