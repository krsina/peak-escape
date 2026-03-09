extends StaticBody2D

var rope_length := 200.0
var lifetime := 20.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, rope_length)
	shape.shape = rect
	shape.position = Vector2(0, rope_length * 0.5)
	add_child(shape)
	set_meta("friction", 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
		set_process(false)
	elif lifetime < 5.0:
		modulate.a = 0.5 + sin(lifetime * 4) * 0.3
	queue_redraw()

func _draw() -> void:
	var segments := 10
	var seg_len := rope_length / segments
	for i in segments:
		var y := i * seg_len
		var sway := sin(y * 0.05 + Time.get_ticks_msec() * 0.002) * 3.0
		draw_line(
			Vector2(sway, y),
			Vector2(sin((y + seg_len) * 0.05 + Time.get_ticks_msec() * 0.002) * 3.0, y + seg_len),
			Color(0.7, 0.55, 0.3),
			3.0
		)
	draw_circle(Vector2(0, 0), 5, Color(0.6, 0.5, 0.35))
	draw_circle(Vector2(0, 0), 3, Color(0.5, 0.4, 0.28))
