extends Area2D

var item_type := "food"
var bob_time := 0.0
var collected := false

const ITEM_COLORS := {
	"food": Color(0.2, 0.8, 0.3),
	"bandage": Color(0.9, 0.9, 0.9),
	"rope": Color(0.75, 0.6, 0.3),
	"piton": Color(0.6, 0.6, 0.7),
}
const GLOW_COLOR := Color(1.0, 0.95, 0.6, 0.3)

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	if has_meta("item_type"):
		item_type = get_meta("item_type")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	monitoring = true

func _process(delta: float) -> void:
	if collected:
		return
	bob_time += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.has_method("add_item"):
		if body.add_item(item_type):
			collected = true
			queue_redraw()
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
			tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
			tw.tween_callback(queue_free)

func _draw() -> void:
	if collected:
		return
	var bob := sin(bob_time * 2.5) * 3.0
	var glow_pulse := 0.3 + absf(sin(bob_time * 2.0)) * 0.2
	draw_circle(Vector2(0, bob), 10, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, glow_pulse))

	var c: Color = ITEM_COLORS.get(item_type, Color.WHITE)
	match item_type:
		"food":
			draw_rect(Rect2(-5, bob - 4, 10, 8), c)
			draw_rect(Rect2(-4, bob - 6, 2, 4), Color(0.4, 0.25, 0.1))
		"bandage":
			draw_rect(Rect2(-5, bob - 3, 10, 6), c)
			draw_line(Vector2(-3, bob), Vector2(3, bob), Color(0.9, 0.2, 0.2), 2.0)
			draw_line(Vector2(0, bob - 3), Vector2(0, bob + 3), Color(0.9, 0.2, 0.2), 2.0)
		"rope":
			draw_arc(Vector2(0, bob), 5, 0, TAU * 0.75, 12, c, 2.0)
			draw_circle(Vector2(4, bob + 3), 2, c.darkened(0.2))
		"piton":
			draw_line(Vector2(0, bob - 6), Vector2(0, bob + 4), c, 3.0)
			draw_line(Vector2(-4, bob - 2), Vector2(4, bob - 2), c.lightened(0.2), 2.0)
