extends Node2D

var start_pos := Vector2.ZERO
var end_pos := Vector2.ZERO
var sag := 40.0
var num_segments := 8
var bridge_color := Color(0.35, 0.28, 0.15)
var leaf_color := Color(0.25, 0.5, 0.2)
var bridge_style := "vine"
var sway_time := 0.0

func setup(from: Vector2, to: Vector2, style: String = "vine") -> void:
	start_pos = from
	end_pos = to
	bridge_style = style
	var span := from.distance_to(to)
	num_segments = maxi(4, int(span / 30.0))
	sag = span * 0.08

	match style:
		"vine":
			bridge_color = Color(0.35, 0.28, 0.15)
			leaf_color = Color(0.25, 0.5, 0.2)
		"chain":
			bridge_color = Color(0.45, 0.45, 0.5)
			leaf_color = Color(0.4, 0.4, 0.4)
		"rope":
			bridge_color = Color(0.55, 0.4, 0.25)
			leaf_color = Color(0.5, 0.38, 0.22)

	_build_collision()
	queue_redraw()

func _catenary_y(t: float) -> float:
	return sag * (4.0 * t * t - 4.0 * t)

func _get_bridge_point(t: float) -> Vector2:
	var base := start_pos.lerp(end_pos, t)
	base.y -= _catenary_y(t)
	var sway_offset := sin(sway_time * 1.2 + t * PI * 2.0) * 2.0
	base.y += sway_offset
	return base

func _build_collision() -> void:
	for i in num_segments:
		var t0 := float(i) / num_segments
		var t1 := float(i + 1) / num_segments
		var p0 := start_pos.lerp(end_pos, t0)
		p0.y -= _catenary_y(t0)
		var p1 := start_pos.lerp(end_pos, t1)
		p1.y -= _catenary_y(t1)
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1)

		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("friction", 0.8)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(seg_len, 8)
		var col := CollisionShape2D.new()
		col.shape = shape
		col.rotation = (p1 - p0).angle()
		body.position = mid
		body.add_child(col)
		add_child(body)

func _process(delta: float) -> void:
	sway_time += delta
	queue_redraw()

func _draw() -> void:
	var prev := _get_bridge_point(0.0)
	var r := RandomNumberGenerator.new()
	r.seed = hash(start_pos)
	for i in range(1, num_segments * 3 + 1):
		var t := float(i) / (num_segments * 3)
		var pt := _get_bridge_point(t)
		draw_line(prev - global_position, pt - global_position, bridge_color, 3.0, true)
		prev = pt

	draw_line(prev - global_position, _get_bridge_point(1.0) - global_position, bridge_color, 3.0, true)

	var darker := bridge_color.darkened(0.15)
	var prev2 := _get_bridge_point(0.0)
	for i in range(1, num_segments * 3 + 1):
		var t := float(i) / (num_segments * 3)
		var pt := _get_bridge_point(t)
		draw_line(
			prev2 - global_position + Vector2(0, 2),
			pt - global_position + Vector2(0, 2),
			darker, 2.0, true
		)
		prev2 = pt

	if bridge_style == "vine":
		for i in range(num_segments + 2):
			var t := r.randf()
			var bp := _get_bridge_point(t) - global_position
			var hang := r.randf_range(6, 16)
			draw_line(bp, bp + Vector2(r.randf_range(-3, 3), hang), leaf_color, 1.5)

	for i in range(num_segments + 1):
		var t := float(i) / num_segments
		var pt := _get_bridge_point(t) - global_position
		draw_circle(pt, 3.0, bridge_color.darkened(0.2))
