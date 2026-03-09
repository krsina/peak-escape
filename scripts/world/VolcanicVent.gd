extends Area2D

const VENT_WIDTH := 40.0
const VENT_HEIGHT := 16.0
const ERUPTION_HEIGHT := 180.0
const ERUPTION_DURATION := 1.2
const COOLDOWN_DURATION := 3.5
const DAMAGE_PER_SEC := 35.0
const KNOCKBACK_UP := -350.0

const VENT_COLOR := Color(0.3, 0.14, 0.06)
const GLOW_COLOR := Color(1.0, 0.45, 0.1)
const FIRE_COLOR := Color(1.0, 0.6, 0.15, 0.7)
const SMOKE_COLOR := Color(0.3, 0.25, 0.2, 0.35)

var erupting := false
var timer := 0.0
var eruption_progress := 0.0
var anim_time := 0.0

var _bodies_inside: Array[Node2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false

	var base_shape := RectangleShape2D.new()
	base_shape.size = Vector2(VENT_WIDTH, VENT_HEIGHT)
	var base_col := CollisionShape2D.new()
	base_col.shape = base_shape
	base_col.position = Vector2(VENT_WIDTH * 0.5, -VENT_HEIGHT * 0.5)
	add_child(base_col)

	var eruption_shape := RectangleShape2D.new()
	eruption_shape.size = Vector2(VENT_WIDTH * 0.6, ERUPTION_HEIGHT)
	var eruption_col := CollisionShape2D.new()
	eruption_col.shape = eruption_shape
	eruption_col.position = Vector2(VENT_WIDTH * 0.5, -ERUPTION_HEIGHT * 0.5 - VENT_HEIGHT)
	eruption_col.name = "EruptionCol"
	add_child(eruption_col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	timer = COOLDOWN_DURATION * randf()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)

func _physics_process(delta: float) -> void:
	anim_time += delta
	timer += delta

	if not erupting:
		if timer >= COOLDOWN_DURATION:
			erupting = true
			monitoring = true
			timer = 0.0
			eruption_progress = 0.0
			AudioManager.play_sfx("eruption")
	else:
		eruption_progress = clampf(timer / ERUPTION_DURATION, 0.0, 1.0)
		for body in _bodies_inside:
			if not is_instance_valid(body):
				continue
			if body.has_method("take_damage"):
				body.take_damage(DAMAGE_PER_SEC * delta)
			if body is CharacterBody2D:
				body.velocity.y = minf(body.velocity.y, KNOCKBACK_UP)
		if timer >= ERUPTION_DURATION:
			erupting = false
			monitoring = false
			timer = 0.0
			_bodies_inside.clear()

	queue_redraw()

func _draw() -> void:
	var cx := VENT_WIDTH * 0.5
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)

	var rock_pts := PackedVector2Array()
	rock_pts.append(Vector2(r.randf_range(-3, 0), 0))
	rock_pts.append(Vector2(VENT_WIDTH * 0.2, -VENT_HEIGHT + r.randf_range(-2, 2)))
	rock_pts.append(Vector2(VENT_WIDTH * 0.4, -VENT_HEIGHT - r.randf_range(2, 6)))
	rock_pts.append(Vector2(VENT_WIDTH * 0.6, -VENT_HEIGHT - r.randf_range(2, 6)))
	rock_pts.append(Vector2(VENT_WIDTH * 0.8, -VENT_HEIGHT + r.randf_range(-2, 2)))
	rock_pts.append(Vector2(VENT_WIDTH + r.randf_range(0, 3), 0))
	draw_colored_polygon(rock_pts, VENT_COLOR)
	draw_polyline(rock_pts, VENT_COLOR.darkened(0.3), 1.5)

	var glow_alpha := 0.3 + sin(anim_time * 4.0) * 0.15
	if erupting:
		glow_alpha = 0.6 + eruption_progress * 0.3
	draw_circle(Vector2(cx, -VENT_HEIGHT * 0.5), VENT_WIDTH * 0.3, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, glow_alpha))

	if not erupting:
		var warn := clampf(timer / COOLDOWN_DURATION, 0.0, 1.0)
		if warn > 0.7:
			var pulse := absf(sin(anim_time * 8.0))
			var smoke_a := (warn - 0.7) / 0.3 * 0.4 * pulse
			for i in range(3):
				var sx := cx + r.randf_range(-8, 8)
				var sy := -VENT_HEIGHT - 10 - i * 12
				draw_circle(Vector2(sx, sy), 5 + i * 2, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, smoke_a))
		return

	var height := ERUPTION_HEIGHT * eruption_progress
	var fade := 1.0 if eruption_progress < 0.7 else (1.0 - eruption_progress) / 0.3

	var half_w := VENT_WIDTH * 0.3
	var fire_pts := PackedVector2Array()
	fire_pts.append(Vector2(cx - half_w, -VENT_HEIGHT))
	fire_pts.append(Vector2(cx - half_w * 0.5, -VENT_HEIGHT - height))
	fire_pts.append(Vector2(cx + half_w * 0.5, -VENT_HEIGHT - height))
	fire_pts.append(Vector2(cx + half_w, -VENT_HEIGHT))
	var fc := FIRE_COLOR
	fc.a *= fade
	draw_colored_polygon(fire_pts, fc)

	var core_pts := PackedVector2Array()
	var core_w := half_w * 0.4
	core_pts.append(Vector2(cx - core_w, -VENT_HEIGHT))
	core_pts.append(Vector2(cx, -VENT_HEIGHT - height * 0.9))
	core_pts.append(Vector2(cx + core_w, -VENT_HEIGHT))
	draw_colored_polygon(core_pts, Color(1.0, 0.9, 0.5, 0.5 * fade))

	r.seed = hash(position) + int(anim_time * 6)
	for i in range(6):
		var px := cx + r.randf_range(-half_w, half_w)
		var py := -VENT_HEIGHT - r.randf_range(10, height * 0.8)
		var pr := r.randf_range(2, 5)
		draw_circle(Vector2(px, py), pr, Color(1.0, 0.7, 0.2, 0.4 * fade))
