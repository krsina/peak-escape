extends Area2D

const DAMAGE := 30.0
const SPIKE_COLOR := Color(0.5, 0.48, 0.45)
const TIP_COLOR := Color(0.75, 0.72, 0.68)
const NUM_SPIKES := 5
const SPIKE_WIDTH := 12.0
const SPIKE_HEIGHT := 18.0

var cooldown := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(NUM_SPIKES * SPIKE_WIDTH, SPIKE_HEIGHT)
	shape.shape = rect
	shape.position = Vector2(NUM_SPIKES * SPIKE_WIDTH * 0.5, -SPIKE_HEIGHT * 0.5)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	monitoring = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if cooldown > 0:
		cooldown -= delta

func _on_body_entered(body: Node2D) -> void:
	if cooldown > 0:
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity.y = -200
		cooldown = 0.8

func _draw() -> void:
	for i in NUM_SPIKES:
		var base_x := i * SPIKE_WIDTH
		var pts := PackedVector2Array([
			Vector2(base_x, 0),
			Vector2(base_x + SPIKE_WIDTH * 0.5, -SPIKE_HEIGHT),
			Vector2(base_x + SPIKE_WIDTH, 0),
		])
		draw_colored_polygon(pts, SPIKE_COLOR)
		draw_line(Vector2(base_x + SPIKE_WIDTH * 0.5, -SPIKE_HEIGHT), Vector2(base_x + SPIKE_WIDTH * 0.5, -SPIKE_HEIGHT + 5), TIP_COLOR, 2.0)
	draw_rect(Rect2(0, -2, NUM_SPIKES * SPIKE_WIDTH, 4), SPIKE_COLOR.darkened(0.15))
