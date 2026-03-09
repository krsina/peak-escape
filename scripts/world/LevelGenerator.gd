extends Node2D

# ── Layout ─────────────────────────────────────────────────────────────
const SEGMENT_W := 28.0
const TOTAL_SEGMENTS := 1200
const TOTAL_WIDTH := SEGMENT_W * TOTAL_SEGMENTS
const START_Y := 560.0
const TOTAL_CLIMB := 8000.0
const GROUND_DEPTH := 520.0
const CHUNK_SEGMENTS := 32
const ZONE_SEGMENTS := 32
const CHECKPOINT_ZONE_INTERVAL := 5

# ── Clearability (derived from player physics) ─────────────────────────
const MAX_VGAP := 105.0
const MAX_HGAP := 230.0
const CAVE_HEIGHT := 240.0
const SKY_OFFSET := 240.0

# ── Biome Colors ───────────────────────────────────────────────────────
const BIOME_COLORS := {
	"beach": {
		"ground": Color(0.82, 0.74, 0.50),
		"sub": Color(0.68, 0.58, 0.38),
		"platform": Color(0.72, 0.62, 0.42),
		"wall": Color(0.65, 0.55, 0.38),
		"cave": Color(0.55, 0.48, 0.32),
	},
	"jungle": {
		"ground": Color(0.28, 0.42, 0.18),
		"sub": Color(0.22, 0.30, 0.12),
		"platform": Color(0.35, 0.28, 0.15),
		"wall": Color(0.25, 0.35, 0.14),
		"cave": Color(0.18, 0.24, 0.10),
	},
	"icelands": {
		"ground": Color(0.78, 0.84, 0.92),
		"sub": Color(0.62, 0.70, 0.82),
		"platform": Color(0.70, 0.78, 0.88),
		"wall": Color(0.60, 0.68, 0.80),
		"cave": Color(0.50, 0.56, 0.68),
	},
	"fire": {
		"ground": Color(0.35, 0.16, 0.08),
		"sub": Color(0.25, 0.10, 0.05),
		"platform": Color(0.40, 0.20, 0.10),
		"wall": Color(0.30, 0.14, 0.06),
		"cave": Color(0.22, 0.08, 0.04),
	},
}

const BIOME_ENCOUNTERS := {
	"beach": {
		"slope": ["cliff_steps", "boulder_field", "switchback", "tide_pools"],
		"underground": ["cave", "secret_cave"],
		"sky": ["floating_islands", "vine_bridge"],
		"special": ["waterfall", "ruins"],
	},
	"jungle": {
		"slope": ["switchback", "boulder_field"],
		"underground": ["cave", "secret_cave"],
		"sky": ["floating_islands", "vine_bridge", "canopy"],
		"special": ["multi_ruins", "ruins"],
	},
	"icelands": {
		"slope": ["cliff_steps", "boulder_field", "frozen_falls"],
		"underground": ["cave", "tunnel", "secret_cave"],
		"sky": ["floating_islands", "vine_bridge"],
		"special": ["waterfall", "multi_ruins"],
	},
	"fire": {
		"slope": ["boulder_field", "cliff_steps", "volcanic_vents"],
		"underground": ["lava_chamber", "tunnel", "secret_cave"],
		"sky": ["floating_islands", "vine_bridge"],
		"special": ["volcanic_vents", "multi_ruins"],
	},
}

# ── State ──────────────────────────────────────────────────────────────
var terrain_node: Node2D
var hazard_node: Node2D
var pickup_node: Node2D
var rng := RandomNumberGenerator.new()
var heights: PackedFloat64Array
var noise_seed := 0.0

# ── Core ───────────────────────────────────────────────────────────────

func _mountain_y(world_x: float) -> float:
	var t := clampf(world_x / TOTAL_WIDTH, 0.0, 1.0)
	var s := 1.0 / (1.0 + exp(-6.0 * (t - 0.45)))
	return START_Y - TOTAL_CLIMB * s

func _noise(x: float, octaves: int = 4, base_freq: float = 0.01) -> float:
	var val := 0.0
	var amp := 1.0
	var freq := base_freq
	var total_amp := 0.0
	for _i in octaves:
		val += sin(x * freq + noise_seed * (freq * 100.0)) * amp
		val += cos(x * freq * 1.7 + noise_seed * 37.0) * amp * 0.5
		total_amp += amp * 1.5
		amp *= 0.5
		freq *= 2.1
	return val / total_amp

func _biome_at(world_x: float) -> String:
	var t := world_x / TOTAL_WIDTH
	if t < 0.25: return "beach"
	if t < 0.5: return "jungle"
	if t < 0.75: return "icelands"
	return "fire"

func _h(seg: int) -> float:
	return heights[clampi(seg, 0, TOTAL_SEGMENTS)]

func generate(t_node: Node2D, h_node: Node2D, p_node: Node2D, seed_val: int = 0) -> void:
	terrain_node = t_node
	hazard_node = h_node
	pickup_node = p_node
	rng.seed = seed_val if seed_val != 0 else randi()
	noise_seed = rng.randf() * 1000.0

	heights.resize(TOTAL_SEGMENTS + 1)
	for i in TOTAL_SEGMENTS + 1:
		var wx := i * SEGMENT_W
		var base := _mountain_y(wx)
		var progress := clampf(wx / TOTAL_WIDTH, 0.0, 1.0)
		var amp := 30.0 + 50.0 * progress
		heights[i] = base + _noise(wx) * amp

	_build_terrain_chunks()
	_build_start_wall()
	_build_helicopter_pad()
	_place_zones()

func get_surface_y_at(world_x: float) -> float:
	if heights.is_empty():
		return START_Y
	var seg_f := world_x / SEGMENT_W
	var seg_i := clampi(int(seg_f), 0, heights.size() - 2)
	var t := clampf(seg_f - seg_i, 0.0, 1.0)
	return lerpf(heights[seg_i], heights[seg_i + 1], t)

# ── Terrain Chunks ─────────────────────────────────────────────────────

func _build_terrain_chunks() -> void:
	var seg := 0
	while seg < TOTAL_SEGMENTS:
		var end_seg := mini(seg + CHUNK_SEGMENTS, TOTAL_SEGMENTS)
		var wx_start := seg * SEGMENT_W
		var biome := _biome_at(wx_start)
		var colors: Dictionary = BIOME_COLORS[biome]
		var pts := PackedVector2Array()
		for i in range(seg, end_seg + 1):
			pts.append(Vector2((i - seg) * SEGMENT_W, heights[i]))
		var block := StaticBody2D.new()
		block.set_script(preload("res://scripts/world/TerrainBlock.gd"))
		block.position = Vector2(wx_start, 0)
		block.setup_polygon(pts, colors["ground"], GROUND_DEPTH, biome == "icelands")
		terrain_node.add_child(block)
		seg = end_seg

func _build_start_wall() -> void:
	var colors: Dictionary = BIOME_COLORS["beach"]
	_add_block(Vector2(-40, heights[0] - 400), Vector2(40, 500), colors["wall"])
	_add_checkpoint(Vector2(80, heights[0]))

func _build_helicopter_pad() -> void:
	var pad_x := TOTAL_SEGMENTS * SEGMENT_W
	var pad_y := heights[TOTAL_SEGMENTS]
	var colors: Dictionary = BIOME_COLORS["fire"]
	_add_block(Vector2(pad_x - 100, pad_y), Vector2(300, 50), colors["ground"].lightened(0.15))
	_add_block(Vector2(pad_x + 200, pad_y), Vector2(260, 50), Color(0.35, 0.35, 0.4))
	_add_block(Vector2(pad_x + 240, pad_y - 2), Vector2(180, 4), Color(1.0, 0.85, 0.2, 0.8))
	var heli := Node2D.new()
	heli.position = Vector2(pad_x + 330, pad_y)
	heli.set_script(preload("res://scripts/world/SummitFlag.gd"))
	pickup_node.add_child(heli)
	_add_checkpoint(Vector2(pad_x, pad_y))

# ── Zone Encounter System ─────────────────────────────────────────────

func _place_zones() -> void:
	var num_zones := ceili(float(TOTAL_SEGMENTS) / ZONE_SEGMENTS)
	for zone_i in num_zones:
		var seg_s := zone_i * ZONE_SEGMENTS
		var seg_e := mini(seg_s + ZONE_SEGMENTS, TOTAL_SEGMENTS)
		if seg_e - seg_s < 8:
			continue
		var zone_x := seg_s * SEGMENT_W
		var zone_w := (seg_e - seg_s) * SEGMENT_W
		var biome := _biome_at(zone_x + zone_w * 0.5)
		var colors: Dictionary = BIOME_COLORS[biome]
		var diff := clampf((zone_x + zone_w * 0.5) / TOTAL_WIDTH, 0.0, 1.0)

		if zone_i > 0 and zone_i % CHECKPOINT_ZONE_INTERVAL == 0:
			_enc_rest_area(seg_s, seg_e, biome, colors, diff)
			_add_zone_pickups(seg_s, seg_e, biome, diff)
			continue

		var encounters: Dictionary = BIOME_ENCOUNTERS[biome]

		var slope_pool: Array = encounters["slope"]
		_call_encounter(slope_pool[rng.randi() % slope_pool.size()], seg_s, seg_e, biome, colors, diff)

		var ug_pool: Array = encounters["underground"]
		if ug_pool.size() > 0 and rng.randf() < 0.65 + diff * 0.2:
			_call_encounter(ug_pool[rng.randi() % ug_pool.size()], seg_s, seg_e, biome, colors, diff)

		var sky_pool: Array = encounters["sky"]
		if sky_pool.size() > 0 and rng.randf() < 0.6 + diff * 0.2:
			_call_encounter(sky_pool[rng.randi() % sky_pool.size()], seg_s, seg_e, biome, colors, diff)

		if rng.randf() < 0.35 + diff * 0.2:
			var spec_pool: Array = encounters["special"]
			if spec_pool.size() > 0:
				_call_encounter(spec_pool[rng.randi() % spec_pool.size()], seg_s, seg_e, biome, colors, diff)

		_add_slope_features(seg_s, seg_e, biome, colors, diff)
		_add_zone_hazards(seg_s, seg_e, biome, diff)
		_add_zone_pickups(seg_s, seg_e, biome, diff)

func _call_encounter(enc: String, seg_s: int, seg_e: int, b: String, c: Dictionary, d: float) -> void:
	match enc:
		"cliff_steps": _enc_cliff_steps(seg_s, seg_e, b, c, d)
		"boulder_field": _enc_boulder_field(seg_s, seg_e, b, c, d)
		"switchback": _enc_switchback(seg_s, seg_e, b, c, d)
		"cave": _enc_cave(seg_s, seg_e, b, c, d)
		"tunnel": _enc_tunnel(seg_s, seg_e, b, c, d)
		"lava_chamber": _enc_lava_chamber(seg_s, seg_e, b, c, d)
		"floating_islands": _enc_floating_islands(seg_s, seg_e, b, c, d)
		"vine_bridge": _enc_vine_bridge(seg_s, seg_e, b, c, d)
		"canopy": _enc_canopy(seg_s, seg_e, b, c, d)
		"waterfall": _enc_waterfall(seg_s, seg_e, b, c, d)
		"ruins": _enc_ruins(seg_s, seg_e, b, c, d)
		"tide_pools": _enc_tide_pools(seg_s, seg_e, b, c, d)
		"frozen_falls": _enc_frozen_falls(seg_s, seg_e, b, c, d)
		"volcanic_vents": _enc_volcanic_vents(seg_s, seg_e, b, c, d)
		"secret_cave": _enc_secret_cave(seg_s, seg_e, b, c, d)
		"multi_ruins": _enc_multi_ruins(seg_s, seg_e, b, c, d)

# ═══════════════════════════════════════════════════════════════════════
#  SLOPE ENCOUNTERS
# ═══════════════════════════════════════════════════════════════════════

func _enc_cliff_steps(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var num_cliffs := rng.randi_range(2, 3)
	var zone_w := (seg_e - seg_s) * SEGMENT_W
	for ci in num_cliffs:
		var cx := seg_s * SEGMENT_W + zone_w * float(ci + 0.5) / (num_cliffs + 0.5) + rng.randf_range(-30, 30)
		var seg := clampi(int(cx / SEGMENT_W), seg_s, seg_e - 1)
		var wy := _h(seg)
		var cliff_h := rng.randf_range(100, 180 + diff * 50)
		var cliff_w := rng.randf_range(22, 40)
		_add_feature("boulder", Vector2(cx, wy - cliff_h), Vector2(cliff_w, cliff_h), colors, biome)

		var num_ledges := ceili(cliff_h / MAX_VGAP) + 1
		var spacing := cliff_h / (num_ledges + 1)
		var side := 1
		for i in num_ledges:
			var ly := wy - cliff_h + (i + 1) * spacing
			var lw := rng.randf_range(50, 90)
			var gap := rng.randf_range(2, 8)
			var lx := cx + (cliff_w + gap if side > 0 else -lw - gap)
			_add_feature(_biome_ledge(biome), Vector2(lx, ly), Vector2(lw, rng.randf_range(10, 15)), colors, biome)
			side *= -1

		if rng.randf() < 0.4:
			_add_feature("boulder", Vector2(cx + rng.randf_range(-40, cliff_w + 10), wy - cliff_h - rng.randf_range(20, 50)), Vector2(rng.randf_range(30, 50), rng.randf_range(12, 20)), colors, biome)

func _enc_boulder_field(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var count := rng.randi_range(5, 8 + int(diff * 3))
	var prev_x := seg_s * SEGMENT_W
	var span := (seg_e - seg_s) * SEGMENT_W
	for i in count:
		var bx := prev_x + rng.randf_range(20, maxf(30, span / count))
		var seg := clampi(int(bx / SEGMENT_W), seg_s, seg_e - 1)
		var by := _h(seg)
		var bw := rng.randf_range(30, 65)
		var bh := rng.randf_range(25, 65)
		_add_feature("boulder", Vector2(bx, by - bh), Vector2(bw, bh), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(bx - 5, by - bh - 6), Vector2(bw + 10, 8), colors, biome)
		if rng.randf() < 0.3:
			var small_w := rng.randf_range(15, 30)
			var small_h := rng.randf_range(12, 25)
			_add_feature("boulder", Vector2(bx + rng.randf_range(-20, bw), by - bh - small_h - rng.randf_range(5, 15)), Vector2(small_w, small_h), colors, biome)
		prev_x = bx + bw + 10

func _enc_switchback(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start_seg := rng.randi_range(seg_s + 2, maxi(seg_s + 4, seg_e - 20))
	var wx := start_seg * SEGMENT_W
	var wy := _h(start_seg)
	var num_steps := rng.randi_range(6, 10 + int(diff * 3))
	var step_h := rng.randf_range(28, minf(48, MAX_VGAP * 0.8))
	var step_w := rng.randf_range(70, 130)
	var dir := 1

	for i in num_steps:
		var zx := wx + dir * rng.randf_range(10, 40)
		var zy := wy - (i + 1) * step_h
		_add_feature(_biome_ledge(biome), Vector2(zx, zy), Vector2(step_w, rng.randf_range(12, 16)), colors, biome)
		if rng.randf() < 0.65:
			var wall_x: float = zx + (step_w if dir > 0 else -rng.randf_range(16, 22))
			var wh := step_h + rng.randf_range(0, 15)
			_add_feature("boulder", Vector2(wall_x, zy - wh + step_h), Vector2(rng.randf_range(16, 24), wh), colors, biome)
		if rng.randf() < 0.25:
			_add_feature(_biome_ledge(biome), Vector2(zx + rng.randf_range(10, step_w - 20), zy - step_h * 0.5), Vector2(rng.randf_range(25, 40), 8), colors, biome)
		dir *= -1

# ═══════════════════════════════════════════════════════════════════════
#  UNDERGROUND ENCOUNTERS
# ═══════════════════════════════════════════════════════════════════════

func _enc_cave(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var cave_segs := rng.randi_range(14, mini(seg_e - seg_s - 2, 28))
	var start := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - cave_segs - 1))
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var cave_w := cave_segs * SEGMENT_W
	var ceil_thick := 28.0
	var cave_h := rng.randf_range(180, CAVE_HEIGHT + 40)

	_add_block(Vector2(wx, wy), Vector2(cave_w, ceil_thick), colors["cave"])
	_add_block(Vector2(wx, wy + cave_h), Vector2(cave_w, ceil_thick), colors["cave"])
	_add_block(Vector2(wx - 18, wy), Vector2(20, cave_h + ceil_thick), colors["cave"])
	_add_block(Vector2(wx + cave_w - 2, wy), Vector2(20, cave_h + ceil_thick), colors["cave"])

	var num_stalactites := rng.randi_range(4, 8)
	for i in num_stalactites:
		var sx := wx + rng.randf_range(20, cave_w - 20)
		var sh := rng.randf_range(18, 50)
		_add_feature("stalactite", Vector2(sx, wy + ceil_thick - 2), Vector2(rng.randf_range(10, 16), sh), colors, biome)

	var num_stalagmites := rng.randi_range(3, 6)
	for i in num_stalagmites:
		var sx := wx + rng.randf_range(20, cave_w - 20)
		var sh := rng.randf_range(15, 40)
		_add_feature("stalagmite", Vector2(sx, wy + cave_h - sh), Vector2(rng.randf_range(12, 18), sh), colors, biome)

	var num_plats := rng.randi_range(5, 9)
	for i in num_plats:
		var px := wx + cave_w * float(i + 0.5) / num_plats + rng.randf_range(-30, 30)
		px = clampf(px, wx + 20, wx + cave_w - 60)
		var py := wy + rng.randf_range(ceil_thick + 20, cave_h - 20)
		_add_feature(_biome_ledge(biome), Vector2(px, py), Vector2(rng.randf_range(45, 85), rng.randf_range(10, 14)), colors, biome)

	var num_inner_walls := rng.randi_range(1, 3)
	for i in num_inner_walls:
		var wwall_x := wx + cave_w * rng.randf_range(0.2, 0.8)
		var wwall_h := rng.randf_range(40, cave_h * 0.5)
		var from_top := rng.randf() < 0.5
		var wwall_y := wy + (ceil_thick if from_top else cave_h - wwall_h)
		_add_feature("boulder", Vector2(wwall_x, wwall_y), Vector2(rng.randf_range(14, 22), wwall_h), colors, biome)

	var entry_x := wx + 4
	var exit_x := wx + cave_w - 50
	var entry_steps := ceili(cave_h / MAX_VGAP) + 1
	for i in entry_steps:
		var ey := wy + (i + 1) * (cave_h / (entry_steps + 1))
		_add_feature(_biome_ledge(biome), Vector2(entry_x, ey), Vector2(rng.randf_range(35, 55), 10), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(exit_x, ey + rng.randf_range(-15, 15)), Vector2(rng.randf_range(35, 55), 10), colors, biome)

	if rng.randf() < 0.55:
		var mp := AnimatableBody2D.new()
		mp.set_script(load("res://scripts/world/MovingPlatform.gd"))
		mp.position = Vector2(wx + cave_w * rng.randf_range(0.3, 0.7), wy + cave_h * rng.randf_range(0.3, 0.7))
		mp.setup(Vector2(55, 10), colors["platform"], Vector2(1, 0), rng.randf_range(50, 100), rng.randf_range(30, 50))
		terrain_node.add_child(mp)

	_add_pickup(Vector2(wx + cave_w * 0.5, wy + cave_h * 0.5), biome)

func _enc_tunnel(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var tun_segs := rng.randi_range(14, mini(seg_e - seg_s - 2, 26))
	var start := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - tun_segs - 1))
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var tun_w := tun_segs * SEGMENT_W
	var tun_h := rng.randf_range(80, 130)
	var top_y := wy + 10

	_add_block(Vector2(wx, top_y), Vector2(tun_w, 20), colors["cave"])
	_add_block(Vector2(wx, top_y + tun_h), Vector2(tun_w, 20), colors["cave"])
	_add_block(Vector2(wx - 16, top_y), Vector2(18, tun_h + 20), colors["cave"])
	_add_block(Vector2(wx + tun_w - 2, top_y), Vector2(18, tun_h + 20), colors["cave"])

	var num_plats := rng.randi_range(5, 9)
	for i in num_plats:
		var px := wx + tun_w * float(i + 0.5) / num_plats + rng.randf_range(-15, 15)
		px = clampf(px, wx + 15, wx + tun_w - 50)
		var py := top_y + rng.randf_range(25, tun_h - 15)
		_add_feature(_biome_ledge(biome), Vector2(px, py), Vector2(rng.randf_range(40, 70), 10), colors, biome)

	var num_stalactites := rng.randi_range(3, 6)
	for i in num_stalactites:
		var sx := wx + rng.randf_range(15, tun_w - 15)
		_add_feature("stalactite", Vector2(sx, top_y + 18), Vector2(10, rng.randf_range(12, 30)), colors, biome)

	var num_obstacles := rng.randi_range(1, 3)
	for i in num_obstacles:
		var ox := wx + tun_w * rng.randf_range(0.15, 0.85)
		var from_top := rng.randf() < 0.5
		var oh := rng.randf_range(25, tun_h * 0.4)
		var oy: float = top_y + (20.0 if from_top else tun_h - oh)
		_add_feature("boulder", Vector2(ox, oy), Vector2(rng.randf_range(14, 22), oh), colors, biome)

	if diff > 0.15:
		var num_spikes := rng.randi_range(1, 2)
		for _si in num_spikes:
			var spike_x := wx + rng.randf_range(tun_w * 0.2, tun_w * 0.8)
			_add_spike(Vector2(spike_x, top_y + tun_h))

	if biome in ["icelands", "fire"]:
		_add_wind_zone(Vector2(wx + tun_w * 0.3, top_y + 25), biome)

	var entry_steps := ceili(tun_h / MAX_VGAP) + 1
	for i in entry_steps:
		var ey := top_y + (i + 1) * (tun_h / (entry_steps + 1))
		_add_feature(_biome_ledge(biome), Vector2(wx + 4, ey), Vector2(40, 10), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(wx + tun_w - 44, ey + rng.randf_range(-10, 10)), Vector2(40, 10), colors, biome)

func _enc_lava_chamber(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var cave_segs := rng.randi_range(14, mini(seg_e - seg_s - 2, 26))
	var start := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - cave_segs - 1))
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var cave_w := cave_segs * SEGMENT_W
	var cave_h := rng.randf_range(180, 260)
	var top_y := wy + 10

	_add_block(Vector2(wx, top_y), Vector2(cave_w, 26), colors["cave"])
	_add_block(Vector2(wx - 18, top_y), Vector2(20, cave_h + 26), colors["cave"])
	_add_block(Vector2(wx + cave_w - 2, top_y), Vector2(20, cave_h + 26), colors["cave"])

	var lava := Area2D.new()
	lava.set_script(load("res://scripts/world/LavaPool.gd"))
	lava.position = Vector2(wx + 16, top_y + cave_h - 40)
	lava.setup(Vector2(cave_w - 32, 40))
	hazard_node.add_child(lava)

	var num_plats := rng.randi_range(6, 10)
	for i in num_plats:
		var px := wx + cave_w * float(i + 0.5) / num_plats + rng.randf_range(-20, 20)
		px = clampf(px, wx + 20, wx + cave_w - 60)
		var py := top_y + rng.randf_range(30, cave_h - 50)
		_add_feature(_biome_ledge(biome), Vector2(px, py), Vector2(rng.randf_range(45, 85), 12), colors, biome)

	var num_stalactites := rng.randi_range(3, 6)
	for i in num_stalactites:
		var sx := wx + rng.randf_range(20, cave_w - 20)
		_add_feature("stalactite", Vector2(sx, top_y + 24), Vector2(12, rng.randf_range(18, 40)), colors, biome)

	var num_rocks := rng.randi_range(1, 3)
	for _ri in num_rocks:
		if rng.randf() < 0.6 + diff * 0.2:
			_add_falling_rock(Vector2(wx + cave_w * rng.randf_range(0.2, 0.8), top_y + 30))

	if rng.randf() < 0.5:
		var mp := AnimatableBody2D.new()
		mp.set_script(load("res://scripts/world/MovingPlatform.gd"))
		mp.position = Vector2(wx + cave_w * 0.5, top_y + cave_h * 0.4)
		mp.setup(Vector2(60, 12), colors["platform"], Vector2(1, 0), rng.randf_range(60, 120), rng.randf_range(30, 50))
		terrain_node.add_child(mp)

	var entry_steps := ceili(cave_h / MAX_VGAP) + 1
	for i in entry_steps:
		var ey := top_y + (i + 1) * (cave_h / (entry_steps + 1))
		_add_feature(_biome_ledge(biome), Vector2(wx + 4, ey), Vector2(45, 10), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(wx + cave_w - 50, ey + rng.randf_range(-10, 10)), Vector2(45, 10), colors, biome)

	_add_pickup(Vector2(wx + cave_w * 0.5, top_y + cave_h * 0.4), biome)

# ═══════════════════════════════════════════════════════════════════════
#  SKY ENCOUNTERS
# ═══════════════════════════════════════════════════════════════════════

func _enc_floating_islands(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var count := rng.randi_range(5, 9)
	var zone_w := (seg_e - seg_s) * SEGMENT_W
	var base_seg := rng.randi_range(seg_s + 1, maxi(seg_s + 3, seg_e - 3))
	var base_y := _h(base_seg) - SKY_OFFSET

	var prev_end_x := seg_s * SEGMENT_W
	for i in count:
		var ix := prev_end_x + rng.randf_range(15, maxf(25, zone_w / count - 10))
		var iy := base_y - rng.randf_range(-50, 80)
		var iw := rng.randf_range(50, 120)
		var ih := rng.randf_range(16, 35)
		_add_feature("boulder", Vector2(ix, iy), Vector2(iw, ih), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(ix + 5, iy - 6), Vector2(iw - 10, 8), colors, biome)

		if rng.randf() < 0.25:
			var sub_w := rng.randf_range(25, 45)
			_add_feature(_biome_ledge(biome), Vector2(ix + rng.randf_range(-10, iw - sub_w), iy + ih + rng.randf_range(15, 40)), Vector2(sub_w, 8), colors, biome)

		if rng.randf() < 0.3:
			_add_pickup(Vector2(ix + iw * 0.5, iy - 25), biome)

		prev_end_x = ix + iw

	var num_mp := rng.randi_range(1, 2)
	for _mi in num_mp:
		if rng.randf() < 0.6:
			var mp := AnimatableBody2D.new()
			mp.set_script(load("res://scripts/world/MovingPlatform.gd"))
			var mp_seg := rng.randi_range(seg_s + 2, maxi(seg_s + 4, seg_e - 2))
			mp.position = Vector2(mp_seg * SEGMENT_W, base_y + rng.randf_range(-30, 40))
			var horizontal := rng.randf() < 0.5
			var dir := Vector2(1, 0) if horizontal else Vector2(0, 1)
			var dist := rng.randf_range(60, 140) if horizontal else rng.randf_range(40, 100)
			mp.setup(Vector2(60, 12), colors["platform"], dir, dist, rng.randf_range(35, 65))
			terrain_node.add_child(mp)

	if diff > 0.25 and rng.randf() < 0.45:
		var mp2 := AnimatableBody2D.new()
		mp2.set_script(load("res://scripts/world/MovingPlatform.gd"))
		var mp2_seg := rng.randi_range(seg_s + 3, maxi(seg_s + 5, seg_e - 3))
		mp2.position = Vector2(mp2_seg * SEGMENT_W, base_y + rng.randf_range(30, 80))
		mp2.set_meta("falling_reset", true)
		mp2.setup(Vector2(55, 10), colors["platform"].darkened(0.1), Vector2(1, 0), rng.randf_range(50, 90), rng.randf_range(35, 55))
		terrain_node.add_child(mp2)

	var entry_seg := clampi(base_seg, seg_s + 1, seg_e - 1)
	var entry_y := _h(entry_seg)
	var steps := ceili(SKY_OFFSET / MAX_VGAP) + 1
	for i in steps:
		var sy := entry_y - (i + 1) * (SKY_OFFSET / (steps + 1))
		var side := 1 if i % 2 == 0 else -1
		_add_feature(_biome_ledge(biome), Vector2(entry_seg * SEGMENT_W + side * rng.randf_range(5, 25), sy), Vector2(rng.randf_range(45, 65), 10), colors, biome)

func _enc_vine_bridge(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var left_seg := rng.randi_range(seg_s + 4, maxi(seg_s + 6, int((seg_s + seg_e) * 0.4)))
	var right_seg := rng.randi_range(int((seg_s + seg_e) * 0.6), maxi(int((seg_s + seg_e) * 0.62), seg_e - 4))
	var left_y := _h(left_seg) - rng.randf_range(60, 120)
	var right_y := _h(right_seg) - rng.randf_range(60, 120)

	_add_feature("boulder", Vector2(left_seg * SEGMENT_W - 20, left_y), Vector2(50, 18), colors, biome)
	_add_feature("boulder", Vector2(right_seg * SEGMENT_W - 20, right_y), Vector2(50, 18), colors, biome)

	var bridge := Node2D.new()
	bridge.set_script(load("res://scripts/world/VineBridge.gd"))
	bridge.position = Vector2.ZERO
	var style := "vine" if biome == "jungle" else ("chain" if biome in ["icelands", "fire"] else "rope")
	bridge.setup(
		Vector2(left_seg * SEGMENT_W + 5, left_y),
		Vector2(right_seg * SEGMENT_W + 5, right_y),
		style
	)
	terrain_node.add_child(bridge)

	var steps_l := ceili(absf(left_y - _h(left_seg)) / MAX_VGAP)
	for i in steps_l:
		var sy := _h(left_seg) - (i + 1) * (absf(left_y - _h(left_seg)) / (steps_l + 1))
		_add_feature(_biome_ledge(biome), Vector2(left_seg * SEGMENT_W - 30, sy), Vector2(50, 10), colors, biome)

func _enc_canopy(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start := rng.randi_range(seg_s + 1, maxi(seg_s + 3, seg_e - 16))
	var canopy_segs := mini(seg_e - start, rng.randi_range(12, 24))
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var canopy_w := canopy_segs * SEGMENT_W
	var num_layers := rng.randi_range(4, 6)

	for layer in num_layers:
		var layer_y := wy - (layer + 1) * rng.randf_range(40, minf(65, MAX_VGAP))
		var num_plats := rng.randi_range(3, 5)
		for _p in num_plats:
			var px := wx + rng.randf_range(0, canopy_w - 60)
			var pw := rng.randf_range(45, 100)
			_add_feature("tree", Vector2(px, layer_y), Vector2(pw, rng.randf_range(12, 18)), colors, biome)

		var num_vines := rng.randi_range(1, 3)
		for _vi in num_vines:
			if rng.randf() < 0.6:
				var vx := wx + rng.randf_range(10, canopy_w - 20)
				var vine_h := rng.randf_range(25, 55)
				_add_feature("vine", Vector2(vx, layer_y + 4), Vector2(10, vine_h), colors, biome)

	var entry_steps := ceili(float(num_layers) * 55.0 / MAX_VGAP) + 1
	for i in entry_steps:
		var ey := wy - (i + 1) * (num_layers * 55.0 / (entry_steps + 1))
		_add_feature(_biome_ledge(biome), Vector2(wx + rng.randf_range(-10, 20), ey), Vector2(rng.randf_range(40, 60), 10), colors, biome)

	_add_pickup(Vector2(wx + canopy_w * 0.5, wy - num_layers * 55 - 20), biome)

# ═══════════════════════════════════════════════════════════════════════
#  SPECIAL ENCOUNTERS
# ═══════════════════════════════════════════════════════════════════════

func _enc_waterfall(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var mid := rng.randi_range(seg_s + 4, maxi(seg_s + 6, seg_e - 4))
	var wx := mid * SEGMENT_W
	var wy := _h(mid)
	var fall_h := rng.randf_range(130, 200)

	_add_feature("boulder", Vector2(wx, wy - fall_h), Vector2(32, fall_h), colors, biome)
	_add_feature("boulder", Vector2(wx - 45, wy - fall_h - 24), Vector2(100, 26), colors, biome)
	_add_feature("boulder", Vector2(wx + 34, wy - fall_h * 0.6), Vector2(rng.randf_range(18, 28), rng.randf_range(30, 60)), colors, biome)

	var pool_style := "frozen" if biome == "icelands" else ("steam" if biome == "fire" else "water")
	var pool := Area2D.new()
	pool.set_script(load("res://scripts/world/WaterPool.gd"))
	pool.position = Vector2(wx - 60, wy - 10)
	pool.setup(Vector2(160, 40), pool_style)
	hazard_node.add_child(pool)

	var num_ledges := ceili(fall_h / MAX_VGAP) + 2
	for i in num_ledges:
		var ly := wy - fall_h + (i + 1) * (fall_h / (num_ledges + 1))
		var side := 1 if i % 2 == 0 else -1
		var lx: float = wx + (34.0 if side > 0 else -rng.randf_range(45, 70))
		_add_feature(_biome_ledge(biome), Vector2(lx, ly), Vector2(rng.randf_range(40, 70), 10), colors, biome)

	for i in range(rng.randi_range(1, 3)):
		var bx := wx + rng.randf_range(-70, 60)
		var by := wy - rng.randf_range(20, fall_h - 20)
		_add_feature("boulder", Vector2(bx, by), Vector2(rng.randf_range(18, 35), rng.randf_range(12, 25)), colors, biome)

	_add_pickup(Vector2(wx - 20, wy - 40), biome)

func _enc_ruins(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start := rng.randi_range(seg_s + 2, maxi(seg_s + 4, seg_e - 14))
	var ruin_segs := rng.randi_range(10, mini(seg_e - start, 20))
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var ruin_w := ruin_segs * SEGMENT_W

	var num_pillars := rng.randi_range(3, 6)
	for i in num_pillars:
		var px := wx + ruin_w * float(i + 0.5) / num_pillars + rng.randf_range(-10, 10)
		var ph := rng.randf_range(60, 150)
		_add_feature("ruin_pillar", Vector2(px, wy - ph), Vector2(rng.randf_range(16, 26), ph), colors, biome)
		_add_feature(_biome_ledge(biome), Vector2(px - 12, wy - ph - 6), Vector2(rng.randf_range(36, 60), 8), colors, biome)

	var num_arches := rng.randi_range(1, 2)
	for _ai in num_arches:
		if rng.randf() < 0.7:
			var ax := wx + ruin_w * rng.randf_range(0.15, 0.7)
			var ay := wy - rng.randf_range(70, 130)
			var arch_w := rng.randf_range(80, 160)
			_add_feature("ruin_arch", Vector2(ax, ay), Vector2(arch_w, rng.randf_range(14, 22)), colors, biome)

	var num_walls := rng.randi_range(2, 5)
	for i in num_walls:
		var wpos_x := wx + rng.randf_range(5, ruin_w - 25)
		var wh := rng.randf_range(25, 70)
		var feature := "mossy_rock" if rng.randf() < 0.5 else "ancient_stone"
		_add_feature(feature, Vector2(wpos_x, wy - wh), Vector2(rng.randf_range(35, 75), wh), colors, biome)

	for _di in range(rng.randi_range(1, 3)):
		var dx := wx + rng.randf_range(10, ruin_w - 30)
		var dw := rng.randf_range(20, 50)
		_add_feature("ancient_stone", Vector2(dx, wy - rng.randf_range(8, 25)), Vector2(dw, rng.randf_range(8, 16)), colors, biome)

	_add_pickup(Vector2(wx + ruin_w * 0.5, wy - 50), biome)

func _enc_rest_area(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var mid := int((seg_s + seg_e) * 0.5)
	var wx := mid * SEGMENT_W
	var wy := _h(mid)
	_add_block(Vector2(wx - 70, wy - 4), Vector2(140, 20), colors["ground"].lightened(0.2))
	_add_checkpoint(Vector2(wx, wy - 4))
	_add_pickup(Vector2(wx - 30, wy - 30), biome)
	if rng.randf() < 0.5:
		_add_pickup(Vector2(wx + 30, wy - 30), biome)

# ═══════════════════════════════════════════════════════════════════════
#  PHASE 2 ENCOUNTERS
# ═══════════════════════════════════════════════════════════════════════

func _enc_tide_pools(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start := rng.randi_range(seg_s + 3, maxi(seg_s + 5, seg_e - 12))
	var span := mini(10, seg_e - start)
	var wx := start * SEGMENT_W
	var wy := _h(start)

	var num_pools := rng.randi_range(2, 4)
	for i in num_pools:
		var px := wx + span * SEGMENT_W * float(i) / (num_pools + 1)
		var pool_w := rng.randf_range(60, 120)
		var pool_h := rng.randf_range(12, 24)
		var water := Area2D.new()
		water.set_script(load("res://scripts/world/WaterPool.gd"))
		water.setup(Vector2(pool_w, pool_h), "water")
		water.position = Vector2(px, wy - pool_h * 0.5)
		terrain_node.add_child(water)

		_add_feature("tide_pool_rock", Vector2(px - 12, wy - pool_h - rng.randf_range(10, 20)), Vector2(rng.randf_range(18, 30), pool_h + 10), colors, biome)
		_add_feature("tide_pool_rock", Vector2(px + pool_w - 8, wy - pool_h - rng.randf_range(10, 20)), Vector2(rng.randf_range(18, 30), pool_h + 10), colors, biome)

	for i in range(num_pools - 1):
		var lx := wx + span * SEGMENT_W * float(i + 1) / (num_pools + 1) + rng.randf_range(10, 30)
		var ledge_y := wy - rng.randf_range(30, 65)
		_add_feature("boulder", Vector2(lx, ledge_y), Vector2(rng.randf_range(40, 70), 12), colors, biome)

func _enc_frozen_falls(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var mid := rng.randi_range(seg_s + 6, maxi(seg_s + 8, seg_e - 6))
	var wx := mid * SEGMENT_W
	var wy := _h(mid)
	var fall_h := rng.randf_range(120, 200 + diff * 60)
	var fall_w := rng.randf_range(30, 50)

	_add_feature("frozen_waterfall", Vector2(wx, wy - fall_h), Vector2(fall_w, fall_h), colors, biome)

	var water := Area2D.new()
	water.set_script(load("res://scripts/world/WaterPool.gd"))
	water.setup(Vector2(fall_w + 40, 20), "frozen")
	water.position = Vector2(wx - 20, wy - 10)
	terrain_node.add_child(water)

	var num_ledges := rng.randi_range(3, 5)
	var side := 1
	for i in num_ledges:
		var ly := wy - fall_h * float(i + 1) / (num_ledges + 1)
		var lx := wx + side * rng.randf_range(fall_w * 0.3, fall_w + 30)
		_add_feature("frozen_rock", Vector2(lx, ly), Vector2(rng.randf_range(35, 55), rng.randf_range(8, 14)), colors, biome)
		side *= -1

	if rng.randf() < 0.5:
		_add_pickup(Vector2(wx + fall_w * 0.5, wy - fall_h - 20), biome)

func _enc_volcanic_vents(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start := rng.randi_range(seg_s + 4, maxi(seg_s + 6, seg_e - 10))
	var span := mini(8, seg_e - start)
	var wx := start * SEGMENT_W
	var wy := _h(start)

	var num_vents := rng.randi_range(2, 3 + int(diff))
	for i in num_vents:
		var vx := wx + span * SEGMENT_W * float(i + 0.5) / (num_vents + 1)
		var vent := Area2D.new()
		vent.set_script(load("res://scripts/world/VolcanicVent.gd"))
		vent.position = Vector2(vx, wy)
		terrain_node.add_child(vent)

		_add_feature("volcanic_rock", Vector2(vx - 20, wy - rng.randf_range(4, 10)), Vector2(rng.randf_range(50, 80), rng.randf_range(12, 20)), colors, biome)

	for i in num_vents:
		var lx := wx + span * SEGMENT_W * float(i + 1) / (num_vents + 1) + rng.randf_range(-15, 15)
		var ly := wy - rng.randf_range(80, 140)
		_add_feature("boulder", Vector2(lx, ly), Vector2(rng.randf_range(40, 65), rng.randf_range(10, 16)), colors, biome)

	if diff > 0.3 and rng.randf() < 0.4:
		var ls := rng.randi_range(start, start + span)
		_add_spike(Vector2(ls * SEGMENT_W + rng.randf_range(0, 20), _h(ls)))

func _enc_secret_cave(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var mid := rng.randi_range(seg_s + 6, maxi(seg_s + 8, seg_e - 6))
	var wx := mid * SEGMENT_W
	var wy := _h(mid)

	var cave_w := rng.randf_range(140, 220)
	var cave_h := rng.randf_range(100, 160)
	var cave_y := wy + rng.randf_range(20, 60)

	var wall := StaticBody2D.new()
	wall.set_script(load("res://scripts/world/SecretWall.gd"))
	wall.setup(Vector2(28, cave_h - 10), colors["wall"].darkened(0.1))
	wall.position = Vector2(wx, cave_y)
	terrain_node.add_child(wall)

	_add_block(Vector2(wx + 30, cave_y - 4), Vector2(cave_w - 32, 14), colors["cave"])
	_add_block(Vector2(wx + 30, cave_y + cave_h - 14), Vector2(cave_w - 32, 14), colors["cave"])
	_add_block(Vector2(wx + cave_w - 4, cave_y), Vector2(14, cave_h), colors["cave"])

	var num_ledges := rng.randi_range(2, 4)
	for i in num_ledges:
		var lx := wx + 40 + rng.randf_range(0, cave_w - 80)
		var ly := cave_y + cave_h * rng.randf_range(0.15, 0.8)
		_add_feature("mossy_rock" if biome == "jungle" else _biome_ledge(biome), Vector2(lx, ly), Vector2(rng.randf_range(30, 55), rng.randf_range(8, 14)), colors, biome)

	_add_pickup(Vector2(wx + cave_w * 0.6, cave_y + cave_h * 0.4), biome)
	_add_pickup(Vector2(wx + cave_w * 0.4, cave_y + cave_h * 0.6), biome)

	if rng.randf() < 0.6:
		var sx := wx + 50 + rng.randf_range(0, cave_w * 0.5)
		_add_feature("stalagmite", Vector2(sx, cave_y + cave_h - rng.randf_range(20, 40)), Vector2(10, rng.randf_range(14, 28)), colors, biome)
	if rng.randf() < 0.6:
		var sx := wx + 50 + rng.randf_range(0, cave_w * 0.5)
		_add_feature("stalactite", Vector2(sx, cave_y + rng.randf_range(6, 16)), Vector2(10, rng.randf_range(14, 28)), colors, biome)

func _enc_multi_ruins(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var start := rng.randi_range(seg_s + 3, maxi(seg_s + 5, seg_e - 20))
	var ruin_segs := mini(18, seg_e - start)
	var wx := start * SEGMENT_W
	var wy := _h(start)
	var ruin_w := ruin_segs * SEGMENT_W

	var num_rooms := rng.randi_range(2, 3)
	var room_w := ruin_w / num_rooms
	for rm in num_rooms:
		var rx := wx + rm * room_w
		var room_h := rng.randf_range(80, 150)
		var ry := wy - room_h

		for side_i in 2:
			var sx := rx if side_i == 0 else rx + room_w - rng.randf_range(14, 20)
			var sw := rng.randf_range(14, 20)
			_add_feature("ancient_stone", Vector2(sx, ry), Vector2(sw, room_h), colors, biome)

		_add_feature("ruin_arch", Vector2(rx + room_w * 0.1, ry), Vector2(room_w * 0.8, rng.randf_range(14, 22)), colors, biome)

		var num_inner := rng.randi_range(1, 3)
		for j in num_inner:
			var ix := rx + room_w * rng.randf_range(0.15, 0.85)
			var iy := wy - room_h * rng.randf_range(0.2, 0.7)
			_add_feature("ancient_stone", Vector2(ix, iy), Vector2(rng.randf_range(30, 55), rng.randf_range(8, 14)), colors, biome)

		if rm < num_rooms - 1:
			var door_y := wy - rng.randf_range(40, 70)
			_add_feature("ruin_pillar", Vector2(rx + room_w - 6, door_y), Vector2(12, wy - door_y), colors, biome)

	_add_pickup(Vector2(wx + ruin_w * 0.5, wy - 50), biome)
	if rng.randf() < 0.5:
		_add_pickup(Vector2(wx + ruin_w * 0.25, wy - 30), biome)

	if rng.randf() < 0.4:
		var sw := StaticBody2D.new()
		sw.set_script(load("res://scripts/world/SecretWall.gd"))
		sw.setup(Vector2(18, rng.randf_range(50, 80)), colors["wall"])
		sw.position = Vector2(wx + ruin_w * rng.randf_range(0.3, 0.7), wy - rng.randf_range(20, 60))
		terrain_node.add_child(sw)
		_add_pickup(Vector2(sw.position.x + 30, sw.position.y + 10), biome)

# ═══════════════════════════════════════════════════════════════════════
#  SLOPE FEATURE FILL
# ═══════════════════════════════════════════════════════════════════════

func _add_slope_features(seg_s: int, seg_e: int, biome: String, colors: Dictionary, diff: float) -> void:
	var step := rng.randi_range(3, 5)
	var seg := seg_s + rng.randi_range(1, 3)
	while seg < seg_e - 1:
		var wx := seg * SEGMENT_W
		var wy := _h(seg)
		var roll := rng.randf()

		if roll < 0.35:
			var bw := rng.randf_range(20, 50)
			var bh := rng.randf_range(15, 40)
			_add_feature(_biome_ledge(biome), Vector2(wx + rng.randf_range(-15, 15), wy - bh), Vector2(bw, bh), colors, biome)
		elif roll < 0.55:
			var lw := rng.randf_range(40, 80)
			var ly := wy - rng.randf_range(30, 80)
			_add_feature(_biome_ledge(biome), Vector2(wx, ly), Vector2(lw, rng.randf_range(8, 14)), colors, biome)
		elif roll < 0.70:
			var bw := rng.randf_range(25, 45)
			var bh := rng.randf_range(25, 55)
			_add_feature("boulder", Vector2(wx, wy - bh), Vector2(bw, bh), colors, biome)
			_add_feature(_biome_ledge(biome), Vector2(wx - 5, wy - bh - 6), Vector2(bw + 10, 8), colors, biome)
		elif roll < 0.82:
			var wall_h := rng.randf_range(40, 90)
			_add_feature("boulder", Vector2(wx, wy - wall_h), Vector2(rng.randf_range(14, 22), wall_h), colors, biome)
			_add_feature(_biome_ledge(biome), Vector2(wx - 20, wy - wall_h - 6), Vector2(rng.randf_range(50, 70), 10), colors, biome)
		else:
			var cluster_n := rng.randi_range(2, 3)
			for _j in cluster_n:
				var cx := wx + rng.randf_range(-25, 40)
				var ch := rng.randf_range(12, 30)
				_add_feature(_biome_ledge(biome), Vector2(cx, wy - ch - rng.randf_range(0, 20)), Vector2(rng.randf_range(18, 35), ch), colors, biome)

		seg += step + rng.randi_range(0, 2)

# ═══════════════════════════════════════════════════════════════════════
#  ZONE HAZARDS & PICKUPS
# ═══════════════════════════════════════════════════════════════════════

func _add_zone_hazards(seg_s: int, seg_e: int, biome: String, diff: float) -> void:
	var num_spikes := rng.randi_range(1, 2 + int(diff * 3))
	for _i in num_spikes:
		if rng.randf() < 0.45 + diff * 0.3:
			var s := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - 1))
			_add_spike(Vector2(s * SEGMENT_W, _h(s)))

	if rng.randf() < 0.35 + diff * 0.3:
		var s := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - 1))
		_add_falling_rock(Vector2(s * SEGMENT_W, _h(s) - rng.randf_range(180, 320)))

	if biome in ["icelands", "fire"] and rng.randf() < 0.4 + diff * 0.2:
		var s := rng.randi_range(seg_s + 1, maxi(seg_s + 2, seg_e - 2))
		_add_wind_zone(Vector2(s * SEGMENT_W, _h(s) - rng.randf_range(40, 110)), biome)

	var num_crumble := rng.randi_range(0, 1 + int(diff * 3))
	for _i in num_crumble:
		if rng.randf() < 0.35 + diff * 0.3:
			var s := rng.randi_range(seg_s + 2, maxi(seg_s + 3, seg_e - 2))
			_add_crumbling_ledge(Vector2(s * SEGMENT_W, _h(s) - rng.randf_range(20, 80)), BIOME_COLORS[biome]["platform"])

func _add_zone_pickups(seg_s: int, seg_e: int, biome: String, diff: float) -> void:
	if rng.randf() < 0.35:
		var s := rng.randi_range(seg_s + 2, maxi(seg_s + 3, seg_e - 2))
		_add_pickup(Vector2(s * SEGMENT_W, _h(s) - 30), biome)
	if rng.randf() < 0.15:
		var s := rng.randi_range(seg_s + 2, maxi(seg_s + 3, seg_e - 2))
		_add_pickup(Vector2(s * SEGMENT_W + rng.randf_range(-30, 30), _h(s) - rng.randf_range(60, 150)), biome)

# ═══════════════════════════════════════════════════════════════════════
#  HELPER: ADD ENTITIES
# ═══════════════════════════════════════════════════════════════════════

func _biome_ledge(biome: String) -> String:
	match biome:
		"beach": return "boulder"
		"jungle": return "tree" if rng.randf() > 0.35 else "vine"
		"icelands": return "icicle" if rng.randf() > 0.4 else "frozen_rock"
		"fire": return "boulder"
	return "boulder"

func _add_feature(ftype: String, pos: Vector2, size: Vector2, colors: Dictionary, biome: String) -> StaticBody2D:
	var color: Color
	match ftype:
		"vine": color = Color(0.22, 0.38, 0.18)
		"icicle": color = Color(0.75, 0.88, 0.98)
		"stalactite": color = colors["cave"].lightened(0.1)
		"stalagmite": color = colors["cave"].lightened(0.15)
		"ruin_pillar": color = Color(0.52, 0.5, 0.46)
		"ruin_arch": color = Color(0.52, 0.5, 0.46)
		"mossy_rock": color = colors["wall"].lerp(Color(0.25, 0.4, 0.2), 0.35)
		"frozen_rock": color = Color(0.65, 0.75, 0.88)
		"tide_pool_rock": color = Color(0.6, 0.55, 0.42)
		"frozen_waterfall": color = Color(0.7, 0.88, 0.98)
		"volcanic_rock": color = Color(0.2, 0.12, 0.08)
		"ancient_stone": color = Color(0.48, 0.46, 0.42)
		_: color = colors["wall"] if ftype == "boulder" else colors["platform"]
	var ice := (biome == "icelands" and ftype in ["icicle", "frozen_rock", "frozen_waterfall"])
	var block := StaticBody2D.new()
	block.set_script(preload("res://scripts/world/TerrainBlock.gd"))
	block.set_meta("feature_type", ftype)
	block.setup(size, color, ice)
	block.position = pos
	terrain_node.add_child(block)
	return block

func _add_block(pos: Vector2, size: Vector2, color: Color, ice: bool = false) -> StaticBody2D:
	var block := StaticBody2D.new()
	block.set_script(preload("res://scripts/world/TerrainBlock.gd"))
	block.set_meta("feature_type", "rock")
	block.setup(size, color, ice)
	block.position = pos
	terrain_node.add_child(block)
	return block

func _add_checkpoint(pos: Vector2) -> void:
	var cp := Area2D.new()
	cp.set_script(preload("res://scripts/world/Checkpoint.gd"))
	cp.position = pos
	pickup_node.add_child(cp)

func _add_pickup(pos: Vector2, biome: String) -> void:
	var types := ["food", "bandage"]
	if biome != "beach":
		types.append("piton")
	if biome in ["icelands", "fire"]:
		types.append("rope")
	var item_type: String = types[rng.randi() % types.size()]
	var pk := Area2D.new()
	pk.set_script(preload("res://scripts/world/Pickup.gd"))
	pk.position = pos
	pk.set_meta("item_type", item_type)
	pickup_node.add_child(pk)

func _add_spike(pos: Vector2) -> void:
	var spike := Area2D.new()
	spike.set_script(preload("res://scripts/world/Spike.gd"))
	spike.position = pos
	hazard_node.add_child(spike)

func _add_crumbling_ledge(pos: Vector2, color: Color) -> void:
	var ledge := StaticBody2D.new()
	ledge.set_script(preload("res://scripts/world/CrumblingLedge.gd"))
	ledge.position = pos
	ledge.set_meta("color", color)
	hazard_node.add_child(ledge)

func _add_falling_rock(pos: Vector2) -> void:
	var rock := Area2D.new()
	rock.set_script(preload("res://scripts/world/FallingRock.gd"))
	rock.position = pos
	hazard_node.add_child(rock)

func _add_wind_zone(pos: Vector2, biome: String) -> void:
	var wz := Area2D.new()
	wz.set_script(preload("res://scripts/world/WindZone.gd"))
	wz.position = pos
	var strength := 140.0 if biome == "icelands" else 220.0
	wz.set_meta("wind_strength", strength)
	hazard_node.add_child(wz)
