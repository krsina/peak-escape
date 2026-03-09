extends StaticBody2D

var block_size := Vector2.ZERO
var block_color := Color.WHITE
var is_ice := false
var edge_color := Color.BLACK
var detail_color := Color.GRAY
var surface_points: PackedVector2Array
var depth := 200.0
var is_polygon := false

func setup(size: Vector2, color: Color, ice: bool = false) -> void:
	block_size = size
	block_color = color
	is_ice = ice
	edge_color = color.darkened(0.25)
	detail_color = color.darkened(0.12)

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size * 0.5
	add_child(col)

	collision_layer = 1
	collision_mask = 0

	if is_ice:
		add_to_group("no_climb")
		set_meta("friction", 0.05)
	else:
		set_meta("friction", 1.0)

	queue_redraw()

func setup_polygon(points: PackedVector2Array, color: Color, ground_depth: float = 200.0, ice: bool = false) -> void:
	is_polygon = true
	surface_points = points
	block_color = color
	depth = ground_depth
	is_ice = ice
	edge_color = color.darkened(0.25)
	detail_color = color.darkened(0.12)

	var poly := _build_fill_polygon()
	if poly.size() < 3:
		return

	var col_poly := CollisionPolygon2D.new()
	col_poly.polygon = poly
	add_child(col_poly)

	collision_layer = 1
	collision_mask = 0

	if is_ice:
		add_to_group("no_climb")
		set_meta("friction", 0.05)
	else:
		set_meta("friction", 1.0)

	queue_redraw()

func _build_fill_polygon() -> PackedVector2Array:
	if surface_points.size() < 2:
		return PackedVector2Array()
	var poly := PackedVector2Array()
	for pt in surface_points:
		poly.append(pt)
	var last := surface_points[surface_points.size() - 1]
	var first := surface_points[0]
	poly.append(Vector2(last.x, last.y + depth))
	poly.append(Vector2(first.x, first.y + depth))
	return poly

func _draw() -> void:
	if is_polygon:
		_draw_polygon_terrain()
	else:
		_draw_block_terrain()

func _make_rock_polygon(rect_min: Vector2, rect_size: Vector2, seed_val: int, num_points: int = 14) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var jitter := minf(rect_size.x, rect_size.y) * 0.12
	var pts := PackedVector2Array()
	var w := rect_size.x
	var h := rect_size.y
	for i in num_points:
		var t := float(i) / num_points
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
		pts.append(rect_min + p)
	return pts

func _draw_block_terrain() -> void:
	if block_size == Vector2.ZERO:
		return
	var feature_type: String = get_meta("feature_type", "rock")
	match feature_type:
		"tree": _draw_tree()
		"vine": _draw_vine()
		"icicle": _draw_icicle()
		"stalactite": _draw_stalactite()
		"stalagmite": _draw_stalagmite()
		"ruin_pillar": _draw_ruin_pillar()
		"ruin_arch": _draw_ruin_arch()
		"mossy_rock": _draw_mossy_rock()
		"frozen_rock": _draw_frozen_rock()
		"tide_pool_rock": _draw_tide_pool_rock()
		"frozen_waterfall": _draw_frozen_waterfall()
		"volcanic_rock": _draw_volcanic_rock()
		"ancient_stone": _draw_ancient_stone()
		_: _draw_rock_or_boulder()

func _draw_rock_or_boulder() -> void:
	var rock_pts := _make_rock_polygon(Vector2.ZERO, block_size, hash(position), 14)
	draw_colored_polygon(rock_pts, block_color)
	draw_polyline(rock_pts, edge_color, 2.0)
	draw_line(rock_pts[0], rock_pts[rock_pts.size() - 1], edge_color, 2.0)
	var top_rock := _make_rock_polygon(Vector2(0, 0), Vector2(block_size.x, 4), hash(position + Vector2(100, 0)), 8)
	draw_colored_polygon(top_rock, block_color.lightened(0.15))
	var bot_rock := _make_rock_polygon(Vector2(0, block_size.y - 3), Vector2(block_size.x, 4), hash(position + Vector2(0, 100)), 8)
	draw_colored_polygon(bot_rock, edge_color.darkened(0.1))
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	for i in range(r.randi_range(2, int(block_size.x * block_size.y / 800))):
		var cx := r.randf_range(4, block_size.x - 4)
		var cy := r.randf_range(4, block_size.y - 4)
		var ln := r.randf_range(4, 12)
		draw_line(Vector2(cx, cy), Vector2(cx + ln, cy + r.randf_range(-2, 2)), detail_color, 1.0)
	if is_ice:
		for i in range(3):
			var ix := r.randf_range(2, block_size.x - 2)
			var iy := r.randf_range(2, block_size.y - 2)
			draw_line(Vector2(ix, iy), Vector2(ix + r.randf_range(-8, 8), iy + r.randf_range(-8, 8)), Color(0.85, 0.92, 1.0, 0.6), 1.0)

func _draw_tree() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var trunk_w := block_size.x * 0.35
	var trunk_x := (block_size.x - trunk_w) * 0.5
	var foliage_h := minf(block_size.y * 0.5, block_size.x * 0.9)
	var trunk_color := block_color.darkened(0.35)
	var foliage_color := Color(0.2, 0.45, 0.18)
	var pts := _make_rock_polygon(Vector2(trunk_x, block_size.y - block_size.y * 0.6), Vector2(trunk_w, block_size.y * 0.6), hash(position), 10)
	draw_colored_polygon(pts, trunk_color)
	draw_polyline(pts, trunk_color.darkened(0.2), 1.5)
	var cx := block_size.x * 0.5
	var cy := block_size.y - foliage_h * 0.6
	var num_pts := 12
	var blob := PackedVector2Array()
	for i in num_pts:
		var angle := TAU * float(i) / num_pts + r.randf_range(-0.2, 0.2)
		var rad := foliage_h * 0.45 * (0.85 + r.randf() * 0.3)
		blob.append(Vector2(cx + cos(angle) * rad, cy - sin(angle) * rad))
	draw_colored_polygon(blob, foliage_color)
	draw_polyline(blob, foliage_color.darkened(0.15), 1.5)
	draw_line(blob[0], blob[blob.size() - 1], foliage_color.darkened(0.15), 1.5)

func _draw_vine() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var segs := maxi(2, int(block_size.y / 18))
	var w := block_size.x * 0.4
	var x0 := block_size.x * 0.5 - w * 0.5
	for s in segs:
		var y0 := block_size.y * float(s) / segs
		var y1 := block_size.y * float(s + 1) / segs
		var sway := r.randf_range(-6, 6)
		var pts := PackedVector2Array()
		pts.append(Vector2(x0 + sway, y0))
		pts.append(Vector2(x0 + w + sway + r.randf_range(-2, 2), y0))
		pts.append(Vector2(x0 + w + sway + r.randf_range(-4, 4), y1))
		pts.append(Vector2(x0 + r.randf_range(-2, 2), y1))
		draw_colored_polygon(pts, block_color)
		draw_polyline(pts, block_color.darkened(0.2), 1.0)
	var leaf_color := Color(0.25, 0.5, 0.2)
	for i in range(3, segs * 2):
		var lx := r.randf_range(2, block_size.x - 6)
		var ly := r.randf_range(4, block_size.y - 4)
		draw_line(Vector2(lx, ly), Vector2(lx + r.randf_range(-4, 4), ly - r.randf_range(4, 10)), leaf_color, 1.5)

func _draw_icicle() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var tip_y := block_size.y
	var base_w := block_size.x * 0.85
	var base_x := (block_size.x - base_w) * 0.5
	var pts := PackedVector2Array()
	pts.append(Vector2(base_x + r.randf_range(-2, 2), 0))
	pts.append(Vector2(base_x + base_w + r.randf_range(-2, 2), 0))
	pts.append(Vector2(block_size.x * 0.5 + r.randf_range(-3, 3), tip_y))
	draw_colored_polygon(pts, block_color)
	draw_polyline(pts, block_color.lightened(0.2), 1.5)
	draw_line(pts[0], pts[pts.size() - 1], block_color.lightened(0.2), 1.5)
	for i in range(2):
		var h := r.randf_range(0.2, 0.7) * block_size.y
		var wx := r.randf_range(2, 6)
		draw_line(Vector2(block_size.x * 0.5, h), Vector2(block_size.x * 0.5 + wx, h + block_size.y * 0.15), block_color.lightened(0.35), 1.0)

func _draw_stalactite() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var pts := PackedVector2Array()
	var w := block_size.x
	var h := block_size.y
	pts.append(Vector2(r.randf_range(-2, 2), 0))
	pts.append(Vector2(w + r.randf_range(-2, 2), 0))
	pts.append(Vector2(w * 0.65 + r.randf_range(-3, 3), h * 0.6))
	pts.append(Vector2(w * 0.5 + r.randf_range(-2, 2), h))
	pts.append(Vector2(w * 0.35 + r.randf_range(-3, 3), h * 0.6))
	draw_colored_polygon(pts, block_color)
	draw_polyline(pts, edge_color, 1.5)
	draw_line(pts[0], pts[pts.size() - 1], edge_color, 1.5)
	var drip_y := h * r.randf_range(0.3, 0.6)
	draw_line(Vector2(w * 0.5, drip_y), Vector2(w * 0.5, drip_y + h * 0.2), block_color.lightened(0.3), 1.0)

func _draw_stalagmite() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var pts := PackedVector2Array()
	var w := block_size.x
	var h := block_size.y
	pts.append(Vector2(w * 0.35 + r.randf_range(-3, 3), h * 0.4))
	pts.append(Vector2(w * 0.5 + r.randf_range(-2, 2), 0))
	pts.append(Vector2(w * 0.65 + r.randf_range(-3, 3), h * 0.4))
	pts.append(Vector2(w + r.randf_range(-2, 2), h))
	pts.append(Vector2(r.randf_range(-2, 2), h))
	draw_colored_polygon(pts, block_color)
	draw_polyline(pts, edge_color, 1.5)
	draw_line(pts[0], pts[pts.size() - 1], edge_color, 1.5)
	draw_line(Vector2(w * 0.5, h * 0.15), Vector2(w * 0.5 + 2, h * 0.35), block_color.lightened(0.25), 1.0)

func _draw_ruin_pillar() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var w := block_size.x
	var h := block_size.y
	var cap_h := minf(8, h * 0.1)
	var base_h := minf(10, h * 0.12)
	draw_rect(Rect2(0, 0, w, cap_h), block_color.lightened(0.1))
	draw_rect(Rect2(2, cap_h, w - 4, h - cap_h - base_h), block_color)
	draw_rect(Rect2(-1, h - base_h, w + 2, base_h), block_color.lightened(0.05))
	draw_rect(Rect2(0, 0, w, h), edge_color, false, 1.5)
	for i in range(r.randi_range(2, 5)):
		var cx := r.randf_range(4, w - 4)
		var cy := r.randf_range(cap_h + 4, h - base_h - 4)
		var len := r.randf_range(4, 14)
		var angle := r.randf_range(-0.5, 0.5)
		draw_line(Vector2(cx, cy), Vector2(cx + cos(angle) * len, cy + sin(angle) * len), edge_color.lightened(0.1), 1.0)
	if r.randf() < 0.5:
		var moss_y := r.randf_range(h * 0.4, h * 0.8)
		var moss_color := Color(0.25, 0.4, 0.2, 0.5)
		for j in range(3):
			var mx := r.randf_range(2, w - 4)
			draw_circle(Vector2(mx, moss_y + r.randf_range(-4, 4)), r.randf_range(2, 5), moss_color)

func _draw_ruin_arch() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var w := block_size.x
	var h := block_size.y
	var pillar_w := maxf(8, w * 0.12)
	var arch_h := maxf(6, h * 0.4)
	draw_rect(Rect2(0, arch_h, pillar_w, h - arch_h), block_color)
	draw_rect(Rect2(w - pillar_w, arch_h, pillar_w, h - arch_h), block_color)
	var arch_pts := PackedVector2Array()
	var steps := 12
	for i in range(steps + 1):
		var t := float(i) / steps
		var ax := lerpf(0, w, t)
		var ay := arch_h - sin(t * PI) * arch_h * 0.8
		arch_pts.append(Vector2(ax, ay))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		var ax := lerpf(0, w, t)
		var ay := arch_h - sin(t * PI) * arch_h * 0.8 + 6
		arch_pts.append(Vector2(ax, ay))
	draw_colored_polygon(arch_pts, block_color.lightened(0.05))
	draw_rect(Rect2(0, 0, w, h), edge_color, false, 1.5)
	for i in range(r.randi_range(1, 3)):
		var cx := r.randf_range(pillar_w + 4, w - pillar_w - 4)
		var cy := r.randf_range(2, arch_h)
		draw_line(Vector2(cx, cy), Vector2(cx + r.randf_range(-6, 6), cy + r.randf_range(2, 8)), edge_color.lightened(0.1), 1.0)

func _draw_mossy_rock() -> void:
	_draw_rock_or_boulder()
	var r := RandomNumberGenerator.new()
	r.seed = hash(position + Vector2(7, 13))
	var moss_color := Color(0.2, 0.42, 0.18, 0.55)
	var num_patches := r.randi_range(3, 7)
	for i in num_patches:
		var mx := r.randf_range(4, block_size.x - 4)
		var my := r.randf_range(4, block_size.y - 4)
		var mr := r.randf_range(3, 8)
		draw_circle(Vector2(mx, my), mr, moss_color)
	for i in range(r.randi_range(2, 5)):
		var lx := r.randf_range(2, block_size.x - 6)
		var ly := r.randf_range(2, block_size.y - 6)
		draw_line(Vector2(lx, ly), Vector2(lx + r.randf_range(-3, 3), ly - r.randf_range(4, 10)), Color(0.25, 0.5, 0.2, 0.4), 1.5)

func _draw_frozen_rock() -> void:
	_draw_rock_or_boulder()
	var r := RandomNumberGenerator.new()
	r.seed = hash(position + Vector2(11, 3))
	var frost := Color(0.8, 0.9, 1.0, 0.35)
	draw_rect(Rect2(0, 0, block_size.x, minf(5, block_size.y * 0.2)), frost)
	for i in range(r.randi_range(2, 5)):
		var ix := r.randf_range(2, block_size.x - 2)
		var iy := r.randf_range(2, block_size.y - 2)
		var len := r.randf_range(5, 12)
		draw_line(Vector2(ix, iy), Vector2(ix + r.randf_range(-len, len), iy + r.randf_range(-len, len)), Color(0.85, 0.92, 1.0, 0.5), 1.0)
	for i in range(r.randi_range(1, 3)):
		var dx := r.randf_range(4, block_size.x - 4)
		var drip_h := r.randf_range(4, 10)
		draw_line(Vector2(dx, block_size.y - 1), Vector2(dx, block_size.y + drip_h), Color(0.75, 0.88, 0.98, 0.6), 1.5)

func _draw_tide_pool_rock() -> void:
	_draw_rock_or_boulder()
	var r := RandomNumberGenerator.new()
	r.seed = hash(position + Vector2(17, 31))
	var pool_color := Color(0.2, 0.45, 0.7, 0.45)
	var sand_color := Color(0.85, 0.78, 0.55, 0.3)
	var num_pools := r.randi_range(1, 3)
	for i in num_pools:
		var px := r.randf_range(6, block_size.x - 10)
		var py := r.randf_range(block_size.y * 0.4, block_size.y - 4)
		var pw := r.randf_range(8, 18)
		var ph := r.randf_range(4, 8)
		var pool_pts := PackedVector2Array()
		for j in range(8):
			var angle := TAU * float(j) / 8 + r.randf_range(-0.3, 0.3)
			pool_pts.append(Vector2(px + cos(angle) * pw * 0.5, py + sin(angle) * ph * 0.5))
		draw_colored_polygon(pool_pts, pool_color)
	draw_rect(Rect2(0, block_size.y - 3, block_size.x, 3), sand_color)
	for i in range(r.randi_range(2, 4)):
		var sx := r.randf_range(2, block_size.x - 4)
		var sy := r.randf_range(block_size.y * 0.7, block_size.y - 2)
		draw_circle(Vector2(sx, sy), r.randf_range(1.5, 3.5), Color(0.9, 0.82, 0.6, 0.4))

func _draw_frozen_waterfall() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var ice_blue := Color(0.7, 0.88, 0.98)
	var ice_white := Color(0.9, 0.95, 1.0, 0.7)
	var ice_dark := Color(0.5, 0.7, 0.85)
	var w := block_size.x
	var h := block_size.y
	var pts := PackedVector2Array()
	pts.append(Vector2(r.randf_range(-2, 4), 0))
	pts.append(Vector2(w + r.randf_range(-4, 2), 0))
	pts.append(Vector2(w * 0.7 + r.randf_range(-3, 3), h * 0.4))
	pts.append(Vector2(w * 0.8 + r.randf_range(-3, 3), h))
	pts.append(Vector2(w * 0.2 + r.randf_range(-3, 3), h))
	pts.append(Vector2(w * 0.3 + r.randf_range(-3, 3), h * 0.4))
	draw_colored_polygon(pts, ice_blue)
	draw_polyline(pts, ice_dark, 2.0)
	draw_line(pts[0], pts[pts.size() - 1], ice_dark, 2.0)
	for i in range(r.randi_range(3, 6)):
		var sx := r.randf_range(w * 0.25, w * 0.75)
		var sy := r.randf_range(4, h - 4)
		var len := r.randf_range(8, h * 0.3)
		draw_line(Vector2(sx, sy), Vector2(sx + r.randf_range(-4, 4), sy + len), ice_white, r.randf_range(1.0, 2.5))
	for i in range(r.randi_range(2, 4)):
		var ix := r.randf_range(w * 0.2, w * 0.8)
		var iy := h + r.randf_range(0, 4)
		var il := r.randf_range(6, 16)
		var iw := r.randf_range(3, 7)
		var icicle_pts := PackedVector2Array()
		icicle_pts.append(Vector2(ix - iw * 0.5, iy))
		icicle_pts.append(Vector2(ix + iw * 0.5, iy))
		icicle_pts.append(Vector2(ix + r.randf_range(-1, 1), iy + il))
		draw_colored_polygon(icicle_pts, Color(0.75, 0.9, 1.0, 0.8))

func _draw_volcanic_rock() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var dark_rock := Color(0.2, 0.12, 0.08)
	var crack_glow := Color(1.0, 0.4, 0.1, 0.7)
	var ember := Color(1.0, 0.6, 0.2, 0.5)
	var rock_pts := _make_rock_polygon(Vector2.ZERO, block_size, hash(position), 14)
	draw_colored_polygon(rock_pts, dark_rock)
	draw_polyline(rock_pts, dark_rock.darkened(0.3), 2.0)
	draw_line(rock_pts[0], rock_pts[rock_pts.size() - 1], dark_rock.darkened(0.3), 2.0)
	for i in range(r.randi_range(3, 7)):
		var cx := r.randf_range(4, block_size.x - 4)
		var cy := r.randf_range(4, block_size.y - 4)
		var len := r.randf_range(6, 18)
		var angle := r.randf_range(-PI, PI)
		var end := Vector2(cx + cos(angle) * len, cy + sin(angle) * len)
		draw_line(Vector2(cx, cy), end, crack_glow, r.randf_range(1.0, 2.5))
	for i in range(r.randi_range(1, 3)):
		var ex := r.randf_range(6, block_size.x - 6)
		var ey := r.randf_range(6, block_size.y - 6)
		draw_circle(Vector2(ex, ey), r.randf_range(2, 4), ember)

func _draw_ancient_stone() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var stone_color := Color(0.48, 0.46, 0.42)
	var worn := stone_color.lightened(0.08)
	var w := block_size.x
	var h := block_size.y
	draw_rect(Rect2(Vector2.ZERO, block_size), stone_color)
	draw_rect(Rect2(Vector2.ZERO, block_size), stone_color.darkened(0.2), false, 2.0)
	var band_h := maxf(3, h * 0.06)
	draw_rect(Rect2(0, 0, w, band_h), worn)
	draw_rect(Rect2(0, h - band_h, w, band_h), worn)
	draw_rect(Rect2(0, h * 0.5 - band_h * 0.5, w, band_h), stone_color.darkened(0.06))
	for i in range(r.randi_range(2, 5)):
		var cx := r.randf_range(4, w - 4)
		var cy := r.randf_range(band_h + 2, h - band_h - 2)
		var len := r.randf_range(4, 12)
		var angle := r.randf_range(-0.5, 0.5)
		draw_line(Vector2(cx, cy), Vector2(cx + cos(angle) * len, cy + sin(angle) * len), stone_color.darkened(0.15), 1.0)
	if r.randf() < 0.4:
		var sx := r.randf_range(w * 0.2, w * 0.8)
		var sy := r.randf_range(h * 0.3, h * 0.7)
		var sw := r.randf_range(6, 14)
		var sh := r.randf_range(6, 14)
		var symbol_pts := PackedVector2Array()
		for j in range(6):
			var angle := TAU * float(j) / 6
			symbol_pts.append(Vector2(sx + cos(angle) * sw * 0.5, sy + sin(angle) * sh * 0.5))
		draw_polyline(symbol_pts, stone_color.darkened(0.12), 1.0)

func _draw_polygon_terrain() -> void:
	if surface_points.size() < 2:
		return
	var fill := _build_fill_polygon()
	if fill.size() < 3:
		return

	draw_colored_polygon(fill, block_color)

	var r := RandomNumberGenerator.new()
	r.seed = hash(position)

	var darker := block_color.darkened(0.08)
	var sub_fill := PackedVector2Array()
	for pt in surface_points:
		sub_fill.append(Vector2(pt.x, pt.y + 6))
	var last := surface_points[surface_points.size() - 1]
	var first := surface_points[0]
	sub_fill.append(Vector2(last.x, last.y + depth))
	sub_fill.append(Vector2(first.x, first.y + depth))
	if sub_fill.size() >= 3:
		draw_colored_polygon(sub_fill, darker)

	var grass_color := block_color.lightened(0.2)
	for i in surface_points.size() - 1:
		var a := surface_points[i]
		var b := surface_points[i + 1]
		var seg_len := a.distance_to(b)
		var steps := maxi(2, int(seg_len / 12))
		var prev := a
		for s in range(1, steps + 1):
			var t := float(s) / steps
			var pt := a.lerp(b, t)
			var perp := Vector2(-(b.y - a.y), b.x - a.x).normalized()
			pt += perp * r.randf_range(-2.5, 2.5)
			draw_line(prev, pt, grass_color, 3.0, true)
			prev = pt
		draw_line(prev, b, grass_color, 3.0, true)

	var total_w := surface_points[surface_points.size() - 1].x - surface_points[0].x
	var num_details := maxi(3, int(total_w / 40.0))
	for i in num_details:
		var t := r.randf()
		var idx := int(t * (surface_points.size() - 1))
		idx = clampi(idx, 0, surface_points.size() - 2)
		var local_t := fmod(t * (surface_points.size() - 1), 1.0)
		var sx := lerpf(surface_points[idx].x, surface_points[idx + 1].x, local_t)
		var sy := lerpf(surface_points[idx].y, surface_points[idx + 1].y, local_t)
		var dy := r.randf_range(8, depth * 0.5)
		var dx := r.randf_range(-6, 6)
		draw_line(Vector2(sx + dx, sy + 4), Vector2(sx + dx + r.randf_range(-4, 4), sy + dy), detail_color, 1.0)

	if not is_ice:
		for i in int(total_w / 24.0):
			var gx := surface_points[0].x + r.randf_range(0, total_w)
			var gi := 0
			for j in surface_points.size() - 1:
				if surface_points[j].x <= gx and surface_points[j + 1].x > gx:
					gi = j
					break
			var gt := 0.0
			var span := surface_points[gi + 1].x - surface_points[gi].x
			if span > 0.01:
				gt = (gx - surface_points[gi].x) / span
			var gy := lerpf(surface_points[gi].y, surface_points[gi + 1].y, gt)
			var blade_h := r.randf_range(3, 8)
			var sway := r.randf_range(-2, 2)
			draw_line(Vector2(gx, gy), Vector2(gx + sway, gy - blade_h), grass_color.darkened(r.randf_range(0, 0.15)), 1.0)
