extends AnimatableBody2D

var move_speed := 60.0
var move_distance := 120.0
var pause_duration := 0.4
var platform_size := Vector2(70, 14)
var platform_color := Color(0.55, 0.5, 0.45)

var origin := Vector2.ZERO
var direction := Vector2.ZERO
var progress := 0.0
var moving_forward := true
var pause_timer := 0.0
var trail_alpha := 0.0

var falling_reset := false
var fall_triggered := false
var fall_velocity := 0.0
var fall_timer := 0.0
const FALL_GRAVITY := 600.0
const FALL_TRIGGER_TIME := 0.8
const FALL_RESET_TIME := 2.5
const FALL_SHAKE_INTENSITY := 2.0
var player_standing := false
var standing_time := 0.0

func setup(size: Vector2, color: Color, dir: Vector2, dist: float, speed: float = 60.0) -> void:
	platform_size = size
	platform_color = color
	direction = dir.normalized()
	move_distance = dist
	move_speed = speed

	var shape := RectangleShape2D.new()
	shape.size = platform_size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = platform_size * 0.5
	add_child(col)

	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true

	queue_redraw()

func _ready() -> void:
	origin = global_position
	falling_reset = get_meta("falling_reset", false)
	if falling_reset:
		var detect := Area2D.new()
		detect.collision_layer = 0
		detect.collision_mask = 2
		var ds := RectangleShape2D.new()
		ds.size = Vector2(platform_size.x + 10, platform_size.y + 16)
		var dc := CollisionShape2D.new()
		dc.shape = ds
		dc.position = platform_size * 0.5 + Vector2(0, -6)
		detect.add_child(dc)
		detect.body_entered.connect(func(b): if b.is_in_group("player"): player_standing = true)
		detect.body_exited.connect(func(b): if b.is_in_group("player"): player_standing = false; standing_time = 0)
		add_child(detect)

func _physics_process(delta: float) -> void:
	if falling_reset:
		_process_falling_reset(delta)
		return

	if pause_timer > 0:
		pause_timer -= delta
		trail_alpha = lerpf(trail_alpha, 0.0, delta * 4.0)
		queue_redraw()
		return

	var spd := move_speed * delta
	if moving_forward:
		progress += spd
		if progress >= move_distance:
			progress = move_distance
			moving_forward = false
			pause_timer = pause_duration
	else:
		progress -= spd
		if progress <= 0:
			progress = 0
			moving_forward = true
			pause_timer = pause_duration

	global_position = origin + direction * progress
	trail_alpha = lerpf(trail_alpha, 0.4, delta * 6.0)
	queue_redraw()

func _process_falling_reset(delta: float) -> void:
	if fall_triggered:
		fall_velocity += FALL_GRAVITY * delta
		global_position.y += fall_velocity * delta
		fall_timer += delta
		if fall_timer >= FALL_RESET_TIME:
			fall_triggered = false
			fall_velocity = 0.0
			fall_timer = 0.0
			standing_time = 0.0
			global_position = origin
		queue_redraw()
		return

	if player_standing:
		standing_time += delta
		if standing_time >= FALL_TRIGGER_TIME:
			fall_triggered = true
			fall_velocity = 0.0
			fall_timer = 0.0
			AudioManager.play_sfx("crumble")
	else:
		standing_time = maxf(0, standing_time - delta * 0.5)

	global_position = origin + direction * progress
	if standing_time > FALL_TRIGGER_TIME * 0.5:
		global_position += Vector2(randf_range(-FALL_SHAKE_INTENSITY, FALL_SHAKE_INTENSITY), randf_range(-FALL_SHAKE_INTENSITY, FALL_SHAKE_INTENSITY))
	queue_redraw()

func _draw() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(origin + Vector2(42, 0))
	var jitter := minf(platform_size.x, platform_size.y) * 0.08
	var pts := PackedVector2Array()
	var w := platform_size.x
	var h := platform_size.y
	var num := 10
	for i in num:
		var t := float(i) / num
		var p: Vector2
		if t < 0.25:
			p = Vector2(lerpf(0, w, t / 0.25), 0)
		elif t < 0.5:
			p = Vector2(w, lerpf(0, h, (t - 0.25) / 0.25))
		elif t < 0.75:
			p = Vector2(lerpf(w, 0, (t - 0.5) / 0.25), h)
		else:
			p = Vector2(0, lerpf(h, 0, (t - 0.75) / 0.25))
		p.x += r.randf_range(-jitter, jitter)
		p.y += r.randf_range(-jitter, jitter)
		pts.append(p)

	var draw_color := platform_color
	if falling_reset and fall_triggered:
		draw_color = platform_color.lerp(Color(0.4, 0.35, 0.3, 0.5), clampf(fall_timer / FALL_RESET_TIME, 0, 1))
	elif falling_reset and standing_time > FALL_TRIGGER_TIME * 0.5:
		var warn := clampf((standing_time - FALL_TRIGGER_TIME * 0.5) / (FALL_TRIGGER_TIME * 0.5), 0, 1)
		draw_color = platform_color.lerp(Color(0.8, 0.3, 0.2), warn * 0.4)

	draw_colored_polygon(pts, draw_color)
	draw_polyline(pts, draw_color.darkened(0.25), 2.0)
	draw_line(pts[0], pts[pts.size() - 1], draw_color.darkened(0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 0), Vector2(w - 2, 0),
		Vector2(w - 2, 3), Vector2(2, 3)
	]), draw_color.lightened(0.2))

	if not falling_reset and trail_alpha > 0.05:
		var trail_dir := -direction * 12.0
		var c := platform_color
		c.a = trail_alpha * 0.3
		for i in range(3):
			var off := trail_dir * (i + 1) * 0.5
			draw_line(Vector2(0, h * 0.5) + off, Vector2(w, h * 0.5) + off, c, 1.0)

	if falling_reset and not fall_triggered:
		var crack_warn := clampf(standing_time / FALL_TRIGGER_TIME, 0, 1)
		if crack_warn > 0.3:
			var num_cracks := int(crack_warn * 4)
			for i in num_cracks:
				var cx := r.randf_range(4, w - 4)
				var cy := r.randf_range(2, h - 2)
				var cl := r.randf_range(4, 10)
				draw_line(Vector2(cx, cy), Vector2(cx + r.randf_range(-cl, cl), cy + r.randf_range(-2, 2)), Color(0.3, 0.25, 0.2, crack_warn * 0.6), 1.0)
