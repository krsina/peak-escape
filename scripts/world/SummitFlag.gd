extends Node2D

var reached := false
var anim_time := 0.0
const BODY_COLOR := Color(0.3, 0.35, 0.38)
const BLADE_COLOR := Color(0.5, 0.55, 0.58)
const LIGHT_COLOR := Color(1, 0.2, 0.1)
const GLOW_COLOR := Color(1, 0.9, 0.5)

func _ready() -> void:
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 50.0
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.monitoring = true
	add_child(area)

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if reached:
		return
	if body.has_method("heal"):
		reached = true
		body.heal(body.MAX_HEALTH)
		body.restore_stamina(body.MAX_STAMINA)
		AudioManager.play_sfx("helicopter")
		GameManager.set_state(GameManager.GameState.ESCAPED)

func _draw() -> void:
	draw_rect(Rect2(-20, -8, 40, 8), BODY_COLOR)
	draw_rect(Rect2(-24, -14, 48, 6), BODY_COLOR.lightened(0.1))

	draw_rect(Rect2(-4, -40, 8, 28), BODY_COLOR.darkened(0.1))

	var blade_rot := anim_time * 12.0
	for i in 4:
		var angle := blade_rot + i * PI * 0.5
		var tip := Vector2(cos(angle) * 40, sin(angle) * 8) + Vector2(0, -42)
		draw_line(Vector2(0, -42), tip, BLADE_COLOR, 3.0)

	draw_rect(Rect2(20, -10, 30, 4), BODY_COLOR)
	draw_line(Vector2(50, -10), Vector2(55, -18), BODY_COLOR, 2.0)
	draw_line(Vector2(50, -6), Vector2(55, 2), BODY_COLOR, 2.0)

	draw_rect(Rect2(-14, -2, 6, 10), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(8, -2, 6, 10), Color(0.25, 0.25, 0.28))

	draw_rect(Rect2(-8, -12, 16, 8), Color(0.6, 0.75, 0.85, 0.5))

	var light_pulse := 0.5 + absf(sin(anim_time * 3.0)) * 0.5
	draw_circle(Vector2(-22, -11), 3, Color(LIGHT_COLOR.r, LIGHT_COLOR.g, LIGHT_COLOR.b, light_pulse))

	if not reached:
		var pulse := 0.3 + absf(sin(anim_time * 2.0)) * 0.4
		draw_circle(Vector2(0, -55), 10, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, pulse))
		draw_string(ThemeDB.fallback_font, Vector2(-30, -68), "ESCAPE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, pulse))
	else:
		var lift := minf(anim_time * 20.0, 0.0)
		draw_circle(Vector2(0, -55 + lift), 14, Color(1, 0.9, 0.3, 0.6))
