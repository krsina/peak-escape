extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL, WALL_GRAB, WALL_CLIMB, WALL_SLIDE, MANTLE, HURT, DEAD }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 620.0
const RUN_SPEED := 280.0
const RUN_ACCEL := 1800.0
const RUN_DECEL := 2000.0
const AIR_ACCEL := 1100.0
const AIR_DECEL := 450.0
const JUMP_FORCE := 520.0
const WALL_JUMP_H := 320.0
const WALL_JUMP_V := 460.0
const WALL_SLIDE_SPEED := 55.0
const WALL_CLIMB_SPEED := 95.0
const COYOTE_DURATION := 0.12
const JUMP_BUFFER_DUR := 0.15
const MANTLE_DURATION := 0.22
const ABOVE_GRAB_MANTLE_DURATION := 0.48
const HURT_DURATION := 0.3
const RESPAWN_DELAY := 1.0
const FALL_DMG_THRESHOLD := 680.0
const FALL_DMG_LETHAL := 1100.0
const FALL_DMG_MULT := 0.06

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN_GRAB := 14.0
const STAMINA_DRAIN_CLIMB := 22.0
const STAMINA_DRAIN_ABOVE_GRAB := 44.0
const STAMINA_RECOVER := 28.0

const SKIN_COLOR := Color(0.95, 0.8, 0.68)
const JACKET_COLOR := Color(0.88, 0.28, 0.15)
const PANTS_COLOR := Color(0.22, 0.24, 0.35)
const HAT_COLOR := Color(0.95, 0.82, 0.18)
const BACKPACK_COLOR := Color(0.52, 0.34, 0.14)
const BOOT_COLOR := Color(0.35, 0.25, 0.18)

var current_state: State = State.FALL
var health := MAX_HEALTH
var stamina := MAX_STAMINA
var facing := 1
var anim_time := 0.0
var coyote_timer := 0.0
var jump_buffer := 0.0
var state_timer := 0.0
var mantle_target := Vector2.ZERO
var mantle_start := Vector2.ZERO
var mantle_duration_override := -1.0
var squash := Vector2.ONE
var fall_start_speed := 0.0
var wall_jump_lockout := 0.0
var was_on_floor := false

var inventory: Array[String] = []
var equipped_idx := 0
const MAX_INVENTORY := 3

@onready var wall_l: RayCast2D = $WallCheckLeft
@onready var wall_r: RayCast2D = $WallCheckRight
@onready var upper_l: RayCast2D = $UpperWallCheckLeft
@onready var upper_r: RayCast2D = $UpperWallCheckRight
@onready var above_ledge_l: RayCast2D = $AboveLedgeLeft
@onready var above_ledge_r: RayCast2D = $AboveLedgeRight
@onready var cam: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	GameManager.set_state(GameManager.GameState.PLAYING)
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.drag_horizontal_enabled = true
		cam.drag_vertical_enabled = true

func _physics_process(delta: float) -> void:
	anim_time += delta
	state_timer += delta
	if jump_buffer > 0:
		jump_buffer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta
	if wall_jump_lockout > 0:
		wall_jump_lockout -= delta
	squash = squash.lerp(Vector2.ONE, delta * 12.0)

	match current_state:
		State.IDLE: _state_idle(delta)
		State.RUN: _state_run(delta)
		State.JUMP: _state_jump(delta)
		State.FALL: _state_fall(delta)
		State.WALL_GRAB: _state_wall_grab(delta)
		State.WALL_CLIMB: _state_wall_climb(delta)
		State.WALL_SLIDE: _state_wall_slide(delta)
		State.MANTLE: _state_mantle(delta)
		State.HURT: _state_hurt(delta)
		State.DEAD: _state_dead(delta)

	if current_state != State.MANTLE:
		move_and_slide()
	if global_position.y > GameManager.active_checkpoint.y + 600 and current_state != State.DEAD:
		_die()
	GameManager.update_progress(global_position.x, global_position.y)
	if was_on_floor and not is_on_floor() and current_state not in [State.JUMP, State.WALL_GRAB, State.WALL_CLIMB, State.MANTLE]:
		coyote_timer = COYOTE_DURATION
	was_on_floor = is_on_floor()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if current_state == State.DEAD:
		return
	if event.is_action_pressed("jump"):
		jump_buffer = JUMP_BUFFER_DUR
	if event.is_action_pressed("use_item"):
		_use_item()
	if event.is_action_pressed("cycle_item"):
		if inventory.size() > 0:
			equipped_idx = (equipped_idx + 1) % inventory.size()

func _change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0

func _state_idle(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, RUN_DECEL * delta)
	_recover_stamina(delta)
	if not is_on_floor():
		_change_state(State.FALL)
		return
	if _wants_jump():
		_do_jump()
		return
	var dir := _input_dir()
	if dir != 0:
		facing = dir
		_change_state(State.RUN)
		return
	if _wants_grab() and _near_wall():
		_start_wall_grab()
		return

func _state_run(delta: float) -> void:
	_apply_gravity(delta)
	_recover_stamina(delta)
	var dir := _input_dir()
	if dir != 0:
		facing = dir
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, RUN_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, RUN_DECEL * delta)
		if absf(velocity.x) < 10:
			_change_state(State.IDLE)
			return
	if not is_on_floor():
		_change_state(State.FALL)
		return
	if _wants_jump():
		_do_jump()
		return
	if _wants_grab() and _near_wall():
		_start_wall_grab()

func _state_jump(delta: float) -> void:
	_apply_gravity(delta)
	_air_move(delta)
	if velocity.y >= 0:
		_change_state(State.FALL)
		fall_start_speed = 0.0
		return
	if _wants_grab() and _near_wall():
		_start_wall_grab()
		return
	if _near_wall() and not _wants_grab():
		_change_state(State.WALL_SLIDE)

func _state_fall(delta: float) -> void:
	_apply_gravity(delta)
	_air_move(delta)
	fall_start_speed = maxf(fall_start_speed, velocity.y)
	if is_on_floor():
		_land()
		return
	if _wants_grab() and _near_wall():
		_start_wall_grab()
		return
	if _near_wall() and not _wants_grab() and velocity.y > 0:
		_change_state(State.WALL_SLIDE)
		return
	if _wants_jump() and coyote_timer > 0:
		_do_jump()

func _state_wall_grab(delta: float) -> void:
	velocity = Vector2.ZERO
	stamina -= STAMINA_DRAIN_GRAB * delta * _biome_stamina_mult()
	if stamina <= 0:
		stamina = 0
		_change_state(State.WALL_SLIDE)
		return
	if not _near_wall():
		_change_state(State.FALL)
		fall_start_speed = 0.0
		return
	if not _wants_grab():
		_change_state(State.FALL)
		fall_start_speed = 0.0
		return
	if _wants_jump():
		_do_wall_jump()
		return
	var vert := Input.get_axis("move_up", "move_down")
	if vert > 0.1:
		if _can_mantle():
			_start_mantle()
			return
		if _can_above_grab() and stamina >= STAMINA_DRAIN_ABOVE_GRAB * _biome_stamina_mult():
			_start_above_mantle()
			return
		_change_state(State.WALL_CLIMB)
		return
	if absf(vert) > 0.1:
		_change_state(State.WALL_CLIMB)
		return
	if _can_mantle():
		_start_mantle()

func _state_wall_climb(delta: float) -> void:
	stamina -= STAMINA_DRAIN_CLIMB * delta * _biome_stamina_mult()
	if stamina <= 0:
		stamina = 0
		_change_state(State.WALL_SLIDE)
		return
	var vert := Input.get_axis("move_up", "move_down")
	velocity = Vector2(0, vert * WALL_CLIMB_SPEED)
	if absf(vert) < 0.1:
		_change_state(State.WALL_GRAB)
		return
	if not _near_wall():
		_change_state(State.FALL)
		fall_start_speed = 0.0
		return
	if not _wants_grab():
		_change_state(State.FALL)
		fall_start_speed = 0.0
		return
	if _wants_jump():
		_do_wall_jump()
		return
	if vert > 0.1:
		if _can_mantle():
			_start_mantle()
			return
		if _can_above_grab() and stamina >= STAMINA_DRAIN_ABOVE_GRAB * _biome_stamina_mult():
			_start_above_mantle()
			return
	if _can_mantle():
		_start_mantle()

func _state_wall_slide(delta: float) -> void:
	velocity.x = 0
	velocity.y = minf(velocity.y + GRAVITY * delta * 0.15, WALL_SLIDE_SPEED)
	_recover_stamina(delta, 0.3)
	if fmod(anim_time, 0.18) < delta:
		var wdir := _wall_dir()
		_spawn_dust(global_position + Vector2(wdir * 10, -12), 2, Color(0.55, 0.5, 0.42, 0.3))
	if is_on_floor():
		_land()
		return
	if not _near_wall():
		_change_state(State.FALL)
		fall_start_speed = velocity.y
		return
	if _wants_grab() and stamina > 0:
		_start_wall_grab()
		return
	if _wants_jump():
		_do_wall_jump()

func _state_mantle(delta: float) -> void:
	var dur := MANTLE_DURATION if mantle_duration_override < 0 else mantle_duration_override
	var t := clampf(state_timer / dur, 0, 1)
	var ease_t := 1.0 - pow(1.0 - t, 3.0)
	global_position = mantle_start.lerp(mantle_target, ease_t)
	velocity = Vector2.ZERO
	if t >= 1.0:
		mantle_duration_override = -1.0
		_change_state(State.IDLE)
		AudioManager.play_sfx("mantle")

func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, 600 * delta)
	if state_timer >= HURT_DURATION:
		if is_on_floor():
			_change_state(State.IDLE)
		else:
			_change_state(State.FALL)
			fall_start_speed = velocity.y

func _state_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, 400 * delta)
	if state_timer >= RESPAWN_DELAY:
		_respawn()

func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

func _air_move(delta: float) -> void:
	if wall_jump_lockout > 0:
		return
	var dir := _input_dir()
	if dir != 0:
		facing = dir
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_DECEL * delta)

func _input_dir() -> int:
	return int(Input.get_axis("move_left", "move_right"))

func _wants_jump() -> bool:
	return jump_buffer > 0

func _wants_grab() -> bool:
	return Input.is_action_pressed("grab")

func _near_wall() -> bool:
	return wall_l.is_colliding() or wall_r.is_colliding()

func _wall_dir() -> int:
	if wall_r.is_colliding():
		return 1
	if wall_l.is_colliding():
		return -1
	return facing

func _can_mantle() -> bool:
	var wdir := _wall_dir()
	var wall_ray: RayCast2D = wall_r if wdir > 0 else wall_l
	var upper_ray: RayCast2D = upper_r if wdir > 0 else upper_l
	return wall_ray.is_colliding() and not upper_ray.is_colliding()

func _can_above_grab() -> bool:
	var wdir := _wall_dir()
	var ray: RayCast2D = above_ledge_r if wdir > 0 else above_ledge_l
	return ray.is_colliding()

func _get_above_ledge_mantle_target() -> Vector2:
	var wdir := _wall_dir()
	var ray: RayCast2D = above_ledge_r if wdir > 0 else above_ledge_l
	var hit: Vector2 = ray.get_collision_point()
	return Vector2(global_position.x + wdir * 20, hit.y - 24)

func _do_jump() -> void:
	velocity.y = -JUMP_FORCE
	jump_buffer = 0
	coyote_timer = 0
	squash = Vector2(0.75, 1.3)
	_change_state(State.JUMP)
	AudioManager.play_sfx("jump")

func _do_wall_jump() -> void:
	var wdir := _wall_dir()
	velocity.x = -wdir * WALL_JUMP_H
	velocity.y = -WALL_JUMP_V
	facing = -wdir
	jump_buffer = 0
	wall_jump_lockout = 0.15
	squash = Vector2(0.7, 1.35)
	_change_state(State.JUMP)
	AudioManager.play_sfx("wall_jump")

func _start_wall_grab() -> void:
	velocity = Vector2.ZERO
	facing = _wall_dir()
	fall_start_speed = 0.0
	_change_state(State.WALL_GRAB)
	AudioManager.play_sfx("grab")

func _start_mantle() -> void:
	var wdir := _wall_dir()
	mantle_start = global_position
	mantle_target = global_position + Vector2(wdir * 24, -36)
	mantle_duration_override = -1.0
	_change_state(State.MANTLE)

func _start_above_mantle() -> void:
	mantle_start = global_position
	mantle_target = _get_above_ledge_mantle_target()
	mantle_duration_override = ABOVE_GRAB_MANTLE_DURATION
	stamina -= STAMINA_DRAIN_ABOVE_GRAB * _biome_stamina_mult()
	if stamina < 0:
		stamina = 0
	_change_state(State.MANTLE)
	AudioManager.play_sfx("grab")

func _land() -> void:
	if fall_start_speed > FALL_DMG_LETHAL:
		_die()
		return
	if fall_start_speed > FALL_DMG_THRESHOLD:
		var dmg := (fall_start_speed - FALL_DMG_THRESHOLD) * FALL_DMG_MULT
		take_damage(dmg)
		squash = Vector2(1.4, 0.6)
		_shake_camera(6.0, 0.25)
		_spawn_dust(global_position, 8, Color(0.6, 0.55, 0.45, 0.6))
		AudioManager.play_sfx("land_hard")
	else:
		squash = Vector2(1.2, 0.8)
		if fall_start_speed > 150:
			_spawn_dust(global_position, 4, Color(0.6, 0.55, 0.45, 0.4))
		AudioManager.play_sfx("land")
	fall_start_speed = 0.0
	if health > 0:
		_change_state(State.IDLE)

func _recover_stamina(delta: float, mult: float = 1.0) -> void:
	stamina = minf(stamina + STAMINA_RECOVER * mult * delta, MAX_STAMINA)

func _biome_stamina_mult() -> float:
	if GameManager.current_biome == "icelands":
		return 1.4
	if GameManager.current_biome == "fire":
		return 1.2
	return 1.0

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		health = 0
		_die()
		return
	velocity.y = -120
	_shake_camera(4.0, 0.15)
	_change_state(State.HURT)
	AudioManager.play_sfx("hurt")

func _die() -> void:
	health = 0
	_shake_camera(8.0, 0.4)
	_spawn_dust(global_position, 10, Color(0.5, 0.4, 0.35, 0.5))
	_change_state(State.DEAD)
	GameManager.set_state(GameManager.GameState.DEAD)
	AudioManager.play_sfx("death")

func _respawn() -> void:
	global_position = GameManager.active_checkpoint
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	velocity = Vector2.ZERO
	fall_start_speed = 0.0
	_change_state(State.FALL)
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.player_respawned.emit()

func heal(amount: float) -> void:
	health = minf(health + amount, MAX_HEALTH)

func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, MAX_STAMINA)

func add_item(item_type: String) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		return false
	inventory.append(item_type)
	GameManager.collect_item(item_type)
	AudioManager.play_sfx("pickup")
	return true

func _use_item() -> void:
	if inventory.is_empty():
		return
	if equipped_idx >= inventory.size():
		equipped_idx = 0
	var item: String = inventory[equipped_idx]
	var used := true
	match item:
		"food":
			restore_stamina(60)
			heal(30)
			_spawn_item_effect(Color(0.2, 0.9, 0.3, 0.7))
			AudioManager.play_sfx("heal")
		"rope":
			used = _place_rope()
		"piton":
			used = _place_piton()
		"bandage":
			heal(50)
			_spawn_item_effect(Color(0.9, 0.3, 0.3, 0.7))
			AudioManager.play_sfx("heal")
	if not used:
		return
	inventory.remove_at(equipped_idx)
	if equipped_idx >= inventory.size():
		equipped_idx = maxi(0, inventory.size() - 1)
	AudioManager.play_sfx("use_item")

func _spawn_item_effect(color: Color) -> void:
	_spawn_dust(global_position + Vector2(0, -16), 12, color)
	_shake_camera(2.0, 0.1)

func _place_rope() -> bool:
	var terrain := get_parent().get_node_or_null("World/Terrain")
	if not terrain:
		push_error("Player: World/Terrain not found, cannot place rope")
		return false
	var rope_scene := preload("res://scripts/world/RopeAnchor.gd")
	var rope := StaticBody2D.new()
	rope.set_script(rope_scene)
	rope.global_position = global_position + Vector2(0, -20)
	terrain.add_child(rope)
	_spawn_item_effect(Color(0.7, 0.55, 0.3, 0.7))
	return true

func _place_piton() -> bool:
	var terrain := get_parent().get_node_or_null("World/Terrain")
	if not terrain:
		push_error("Player: World/Terrain not found, cannot place piton")
		return false
	var piton := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 12)
	shape.shape = rect
	piton.add_child(shape)
	piton.collision_layer = 1
	piton.add_to_group("piton")
	piton.global_position = global_position + Vector2(facing * 20, -10)
	piton.set_meta("lifetime", 15.0)
	terrain.add_child(piton)
	_spawn_item_effect(Color(0.6, 0.6, 0.7, 0.7))
	return true

func apply_wind(force: Vector2, delta: float) -> void:
	velocity += force * delta

func _shake_camera(intensity: float, duration: float) -> void:
	if not cam:
		return
	var tw := create_tween()
	var steps := int(duration / 0.04)
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1) * intensity * fade, randf_range(-1, 1) * intensity * fade), 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)

func _spawn_dust(pos: Vector2, amount: int, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.4
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 50.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 180)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.global_position = pos
	get_parent().add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, squash)
	var d := facing
	var leg_anim := sin(anim_time * 10.0) * 4.0 if current_state == State.RUN else 0.0

	draw_rect(Rect2(-5, -8 + leg_anim * 0.5, 4, 8 - leg_anim * 0.3), PANTS_COLOR)
	draw_rect(Rect2(1, -8 - leg_anim * 0.5, 4, 8 + leg_anim * 0.3), PANTS_COLOR)
	draw_rect(Rect2(-6, -7 + leg_anim * 0.5, 5, 3), BOOT_COLOR)
	draw_rect(Rect2(1, -7 - leg_anim * 0.5, 5, 3), BOOT_COLOR)

	draw_rect(Rect2(-7, -22, 14, 14), JACKET_COLOR)
	var bp_x := -8 * d
	draw_rect(Rect2(bp_x, -21, 5 * d, 10), BACKPACK_COLOR)

	match current_state:
		State.WALL_GRAB, State.WALL_CLIMB:
			draw_line(Vector2(0, -20), Vector2(8 * d, -30), SKIN_COLOR, 2.0)
			draw_line(Vector2(0, -16), Vector2(6 * d, -26), SKIN_COLOR, 2.0)
		State.JUMP:
			draw_line(Vector2(-5, -20), Vector2(-10, -28), SKIN_COLOR, 2.0)
			draw_line(Vector2(5, -20), Vector2(10, -28), SKIN_COLOR, 2.0)
		State.FALL, State.WALL_SLIDE:
			draw_line(Vector2(-5, -20), Vector2(-12, -27), SKIN_COLOR, 2.0)
			draw_line(Vector2(5, -20), Vector2(12, -27), SKIN_COLOR, 2.0)
		State.HURT:
			draw_line(Vector2(-5, -18), Vector2(-12, -14), SKIN_COLOR, 2.0)
			draw_line(Vector2(5, -18), Vector2(12, -14), SKIN_COLOR, 2.0)
		State.DEAD:
			draw_set_transform(Vector2.ZERO, PI / 2.0, squash)
			draw_rect(Rect2(-7, -22, 14, 22), JACKET_COLOR.darkened(0.3))
			draw_circle(Vector2(0, -24), 5, SKIN_COLOR.darkened(0.2))
			return
		_:
			var sw := sin(anim_time * 8.0) * 10.0 if current_state == State.RUN else 0.0
			draw_line(Vector2(-5, -18), Vector2(-10, -10 + sw), SKIN_COLOR, 2.0)
			draw_line(Vector2(5, -18), Vector2(10, -10 - sw), SKIN_COLOR, 2.0)

	draw_circle(Vector2(0, -27), 5, SKIN_COLOR)
	draw_circle(Vector2(d * 2, -28), 1.5, Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(-6, -34, 12, 5), HAT_COLOR)
	draw_rect(Rect2(-8, -30, 16, 2), HAT_COLOR)

	if stamina < MAX_STAMINA * 0.3 and current_state in [State.WALL_GRAB, State.WALL_CLIMB]:
		var flash := absf(sin(anim_time * 6.0))
		draw_circle(Vector2(0, -40), 3, Color(1, 0.3, 0.1, flash * 0.8))

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
