class_name Scenery
extends RefCounted

# The trash can and the six world backgrounds.

const METAL := Color("aebdcc")
const METAL_LIGHT := Color("d5dfe9")
const METAL_DARK := Color("7f90a3")
const INSIDE := Color("2a2238")

const RIM_Y := -190.0
const RIM_RX := 98.0
const RIM_RY := 18.0


# --- Trash can (bottom centre is 0,0) --------------------------------------------

static func bin_back() -> Array:
	return Art.cached("bin_back", func() -> Array:
		return [
			[Art.E(Vector2(0, RIM_Y), RIM_RX, RIM_RY, METAL_LIGHT)],
			[Art.E(Vector2(0, RIM_Y + 1), RIM_RX - 10, RIM_RY - 6, INSIDE, 0.0, false)],
		])


static func bin_front() -> Array:
	return Art.cached("bin_front", func() -> Array:
		var body := PackedVector2Array()
		for i in 25:
			var a := PI * i / 24.0
			body.append(Vector2(cos(a) * RIM_RX, RIM_Y + sin(a) * RIM_RY))
		body.append_array(Art.V([Vector2(-80, -10), Vector2(-72, 0), Vector2(72, 0), Vector2(80, -10)]))
		var shade := Art.V([Vector2(52, RIM_Y + 14), Vector2(80, RIM_Y + 8), Vector2(80, -10), Vector2(72, 0), Vector2(46, 0)])
		var details := [Art.P(shade, Color(0.25, 0.3, 0.45, 0.18), false)]
		for x in [-56, -28, 0, 28]:
			details.append(Art.L(Art.V([Vector2(x * 1.05, RIM_Y + 26), Vector2(x * 0.85, -20)]), 7, Color(1, 1, 1, 0.22), false))
			details.append(Art.L(Art.V([Vector2(x * 1.05 + 9, RIM_Y + 26), Vector2(x * 0.85 + 8, -20)]), 3, Color(0.2, 0.25, 0.4, 0.2), false))
		var band_hi := PackedVector2Array()
		var band_lo := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			band_hi.append(Vector2(lerpf(-92, 92, t), -148 + sin(t * PI) * 8))
			band_lo.append(Vector2(lerpf(-82, 82, t), -42 + sin(t * PI) * 7))
		var rim := PackedVector2Array()
		for i in 25:
			var a := PI * i / 24.0
			rim.append(Vector2(cos(a) * RIM_RX, RIM_Y + sin(a) * RIM_RY))
		return [
			[Art.P(body, METAL)],
			details,
			[Art.L(band_hi, 6, METAL_DARK)],
			[Art.L(band_lo, 6, METAL_DARK)],
			[Art.L(rim, 9, METAL_LIGHT)],
			[Art.L(Art.arc(Vector2(-104, -150), 14, PI * 0.6, PI * 1.4, 8), 6, METAL_DARK),
				Art.L(Art.arc(Vector2(104, -150), 14, -PI * 0.4, PI * 0.4, 8), 6, METAL_DARK)],
		])


static func lid() -> Array:
	return Art.cached("lid", func() -> Array:
		var dome := PackedVector2Array()
		for i in 21:
			var a := PI + PI * i / 20.0
			dome.append(Vector2(cos(a) * 88, sin(a) * 30))
		return [
			[Art.L(Art.V([Vector2(-16, -28), Vector2(-16, -42), Vector2(16, -42), Vector2(16, -28)]), 7, METAL_DARK)],
			[Art.P(dome, METAL), Art.E(Vector2(0, 0), 104, 20, METAL_LIGHT)],
			[Art.E(Vector2(-30, -16), 26, 6, Color(1, 1, 1, 0.4), -0.1, false)],
		])


# --- Backgrounds ---------------------------------------------------------------------

static func ground_y(rect: Rect2) -> float:
	return rect.position.y + rect.size.y * (0.72 if rect.size.x >= rect.size.y else 0.66)


static func background(c: CanvasItem, world: int, rect: Rect2, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + world
	match world:
		0: _backyard(c, rect, t, rng)
		1: _park(c, rect, t, rng)
		2: _pizza(c, rect, t, rng)
		3: _beach(c, rect, t, rng)
		4: _mall(c, rect, t, rng)
		_: _space(c, rect, t, rng)


static func grad(c: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(Art.V([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func cloud(c: CanvasItem, p: Vector2, s: float, col := Color(1, 1, 1, 0.95)) -> void:
	for b in [[Vector2(-38, 6), 24.0], [Vector2(-10, -10), 32.0], [Vector2(24, -2), 27.0], [Vector2(46, 10), 18.0], [Vector2(4, 12), 22.0]]:
		c.draw_circle(p + b[0] * s, b[1] * s, col, true, -1.0, true)


static func glow(c: CanvasItem, p: Vector2, r: float, col: Color, rings := 4) -> void:
	for i in rings:
		var k := 1.0 - float(i) / rings
		c.draw_circle(p, r * (1.0 + k * 1.2), Color(col, col.a * 0.12), true, -1.0, true)
	c.draw_circle(p, r, col, true, -1.0, true)


static func hills(c: CanvasItem, rect: Rect2, base_y: float, height: float, col: Color, waves: float, phase: float) -> void:
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var x := rect.position.x + rect.size.x * i / n
		var y := base_y - height * (0.6 + 0.4 * sin(i * waves / n * TAU + phase))
		pts.append(Vector2(x, y))
	pts.append(Vector2(rect.end.x, rect.end.y))
	pts.append(Vector2(rect.position.x, rect.end.y))
	c.draw_colored_polygon(pts, col)


static func outlined_rect(c: CanvasItem, r: Rect2, col: Color, radius := 4.0, w := 4.0) -> void:
	c.draw_colored_polygon(Art.rrect(r.grow(w), radius + w), Art.OL)
	c.draw_colored_polygon(Art.rrect(r, radius), col)


static func _drift(rect: Rect2, base: float, t: float, speed: float) -> float:
	return rect.position.x + fposmod(base * rect.size.x + t * speed, rect.size.x + 260.0) - 130.0


static func _backyard(c: CanvasItem, rect: Rect2, t: float, rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("7ccdfa"), Color("ffe6bd"))
	glow(c, Vector2(rect.position.x + rect.size.x * 0.82, rect.position.y + rect.size.y * 0.17), 46, Color("fff1a0"))
	for i in 3:
		cloud(c, Vector2(_drift(rect, 0.15 + i * 0.37, t, 9.0 + i * 3.0), rect.position.y + rect.size.y * (0.12 + i * 0.07)), 0.9 + i * 0.2)
	hills(c, rect, gy - 70, 50, Color("a7dd7a"), 1.4, 0.5)
	# Wooden fence.
	var plank := 46.0
	var x := rect.position.x - 10.0
	var top := gy - 150.0
	c.draw_rect(Rect2(rect.position.x, top + 36, rect.size.x, 16), Art.OL)
	c.draw_rect(Rect2(rect.position.x, top + 104, rect.size.x, 16), Art.OL)
	while x < rect.end.x:
		var h := rng.randf_range(-8, 8)
		var pts := Art.V([Vector2(x + 4, gy), Vector2(x + 4, top + 14 + h), Vector2(x + plank * 0.5, top + h), Vector2(x + plank - 4, top + 14 + h), Vector2(x + plank - 4, gy)])
		c.draw_polyline(Art.closed(pts), Art.OL, 7.0, true)
		c.draw_colored_polygon(pts, Color("d39a63") if floori(x / plank) % 2 == 0 else Color("c88c56"))
		c.draw_line(Vector2(x + 14, top + 30 + h), Vector2(x + 14, gy - 12), Color(0.5, 0.3, 0.15, 0.25), 3.0)
		x += plank
	c.draw_rect(Rect2(rect.position.x, top + 39, rect.size.x, 10), Color("b57a46"))
	c.draw_rect(Rect2(rect.position.x, top + 107, rect.size.x, 10), Color("b57a46"))
	# Bushes and grass.
	for i in 5:
		var bx := rect.position.x + rect.size.x * (0.05 + i * 0.23) + rng.randf_range(-20, 20)
		for b in [[Vector2(-30, 0), 30.0], [Vector2(0, -16), 36.0], [Vector2(32, -2), 28.0]]:
			c.draw_circle(Vector2(bx, gy - 6) + b[0], b[1] + 4, Art.OL, true, -1.0, true)
		for b in [[Vector2(-30, 0), 30.0], [Vector2(0, -16), 36.0], [Vector2(32, -2), 28.0]]:
			c.draw_circle(Vector2(bx, gy - 6) + b[0], b[1], Color("4fae3d"), true, -1.0, true)
	c.draw_rect(Rect2(rect.position.x, gy, rect.size.x, rect.end.y - gy), Color("6cc24a"))
	c.draw_rect(Rect2(rect.position.x, gy - 3, rect.size.x, 6), Art.OL)
	_tufts(c, rect, gy, Color("4fa53a"), rng)


static func _tufts(c: CanvasItem, rect: Rect2, gy: float, col: Color, rng: RandomNumberGenerator, count := 18) -> void:
	for i in count:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(gy + 20, rect.end.y - 10))
		c.draw_polyline(Art.V([p + Vector2(-8, 0), p + Vector2(-4, -12), p, p + Vector2(4, -14), p + Vector2(8, 0)]), col, 3.0, true)


static func _tree(c: CanvasItem, p: Vector2, s: float, crown: Color) -> void:
	outlined_rect(c, Rect2(p + Vector2(-9, -70) * s, Vector2(18, 72) * s), Color("8a5a35"), 4)
	var balls := [[Vector2(0, -110), 46.0], [Vector2(-36, -84), 34.0], [Vector2(36, -86), 36.0], [Vector2(0, -76), 34.0]]
	for b in balls:
		c.draw_circle(p + b[0] * s, (b[1] + 4.0) * s, Art.OL, true, -1.0, true)
	for b in balls:
		c.draw_circle(p + b[0] * s, b[1] * s, crown, true, -1.0, true)
	c.draw_circle(p + Vector2(-14, -124) * s, 12 * s, Color(1, 1, 1, 0.18), true, -1.0, true)


static func _park(c: CanvasItem, rect: Rect2, t: float, rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("6cc8ff"), Color("d9f4ff"))
	for i in 4:
		cloud(c, Vector2(_drift(rect, 0.1 + i * 0.29, t, 7.0 + i * 2.0), rect.position.y + rect.size.y * (0.1 + (i % 2) * 0.1)), 0.8 + (i % 3) * 0.2)
	hills(c, rect, gy - 40, 90, Color("9be07a"), 1.1, 1.8)
	hills(c, rect, gy, 60, Color("7fd060"), 1.7, 0.2)
	_tree(c, Vector2(rect.position.x + rect.size.x * 0.12, gy + 6), 1.15, Color("58b947"))
	_tree(c, Vector2(rect.position.x + rect.size.x * 0.9, gy + 2), 1.0, Color("4fae3d"))
	_tree(c, Vector2(rect.position.x + rect.size.x * 0.72, gy - 26), 0.7, Color("6cc24a"))
	c.draw_rect(Rect2(rect.position.x, gy, rect.size.x, rect.end.y - gy), Color("74c94e"))
	c.draw_rect(Rect2(rect.position.x, gy - 3, rect.size.x, 6), Art.OL)
	var cx := rect.get_center().x
	var path := Art.V([Vector2(cx - 50, gy), Vector2(cx + 50, gy), Vector2(cx + 200, rect.end.y), Vector2(cx - 200, rect.end.y)])
	c.draw_colored_polygon(path, Color("f0d9a8"))
	for i in 14:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(gy + 16, rect.end.y - 8))
		if absf(p.x - cx) < 160:
			continue
		var col: Color = [Art.PINK, Art.YELLOW, Art.WHITE, Color("b98aff")][i % 4]
		for k in 5:
			c.draw_circle(p + Vector2(cos(k * TAU / 5), sin(k * TAU / 5)) * 5, 4, col, true, -1.0, true)
		c.draw_circle(p, 3, Art.ORANGE, true, -1.0, true)
	_tufts(c, rect, gy, Color("58b040"), rng, 12)


static func _pizza(c: CanvasItem, rect: Rect2, t: float, rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("1d1f4d"), Color("6a3f8f"))
	for i in 40:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, gy - 150))
		var tw := 0.5 + 0.5 * sin(t * 2.0 + i)
		c.draw_circle(p, 1.2 + tw * 1.3, Color(1, 1, 1, 0.4 + tw * 0.5), true, -1.0, true)
	var moon := Vector2(rect.position.x + rect.size.x * 0.8, rect.position.y + rect.size.y * 0.16)
	glow(c, moon, 34, Color("fff4c8"))
	c.draw_circle(moon + Vector2(-10, -6), 7, Color("eadfb0"), true, -1.0, true)
	c.draw_circle(moon + Vector2(12, 8), 5, Color("eadfb0"), true, -1.0, true)
	# Buildings with lit windows.
	var x := rect.position.x - 20.0
	while x < rect.end.x:
		var w := rng.randf_range(80, 140)
		var h := rng.randf_range(140, 300)
		var b := Rect2(x, gy - h, w - 8, h)
		c.draw_rect(b, Color("2c2552"))
		var wy := b.position.y + 16
		while wy < gy - 40:
			var wx := b.position.x + 12
			while wx < b.end.x - 18:
				var lit := rng.randf() < 0.45
				c.draw_rect(Rect2(wx, wy, 14, 18), Color("ffd66b") if lit else Color("3c3468"))
				wx += 26
			wy += 32
		x += w
	# Brick wall.
	var wall := Rect2(rect.position.x, gy - 110, rect.size.x, 110)
	c.draw_rect(wall, Color("b4533e"))
	var row := 0
	var by := wall.position.y
	while by < gy:
		var off := 0.0 if row % 2 == 0 else 24.0
		c.draw_line(Vector2(wall.position.x, by), Vector2(wall.end.x, by), Color("8c3a2c"), 3.0)
		var bx := wall.position.x - off
		while bx < wall.end.x:
			c.draw_line(Vector2(bx, by), Vector2(bx, by + 22), Color("8c3a2c"), 3.0)
			bx += 48
		by += 22
		row += 1
	c.draw_rect(Rect2(wall.position.x, wall.position.y - 3, wall.size.x, 6), Art.OL)
	# Neon pizza sign.
	var sign_pos := Vector2(rect.position.x + rect.size.x * 0.17, gy - 190)
	var flicker := 0.85 + 0.15 * sin(t * 13.0) * sin(t * 3.0)
	glow(c, sign_pos, 50, Color(1.0, 0.3, 0.6, 0.25 * flicker), 3)
	Art.panel(c, Rect2(sign_pos - Vector2(52, 44), Vector2(104, 88)), Color("3a2a6a"), 16, 0, 4)
	Art.item(c, "pizza", sign_pos, 0.9)
	# Street lamp.
	var lamp := Vector2(rect.position.x + rect.size.x * 0.86, gy)
	outlined_rect(c, Rect2(lamp + Vector2(-5, -230), Vector2(10, 230)), Color("39345a"), 3)
	glow(c, lamp + Vector2(0, -236), 16, Color("fff2b0"))
	c.draw_colored_polygon(Art.V([lamp + Vector2(-14, -226), lamp + Vector2(14, -226), lamp + Vector2(90, 0), lamp + Vector2(-90, 0)]), Color(1, 0.95, 0.6, 0.08))
	c.draw_rect(Rect2(rect.position.x, gy, rect.size.x, rect.end.y - gy), Color("4a4560"))
	c.draw_rect(Rect2(rect.position.x, gy, rect.size.x, 22), Color("8c86a3"))
	c.draw_rect(Rect2(rect.position.x, gy - 3, rect.size.x, 6), Art.OL)
	c.draw_rect(Rect2(rect.position.x, gy + 20, rect.size.x, 4), Art.OL)


static func _beach(c: CanvasItem, rect: Rect2, t: float, rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("57c7ff"), Color("fff0c8"))
	glow(c, Vector2(rect.position.x + rect.size.x * 0.7, rect.position.y + rect.size.y * 0.22), 52, Color("ffe36b"))
	for i in 2:
		cloud(c, Vector2(_drift(rect, 0.2 + i * 0.5, t, 6.0), rect.position.y + rect.size.y * (0.1 + i * 0.08)), 0.9)
	var sea_top := gy - 80.0
	c.draw_rect(Rect2(rect.position.x, sea_top, rect.size.x, gy - sea_top + 30), Color("2ea3dd"))
	for row in 3:
		var pts := PackedVector2Array()
		for i in 41:
			var x := rect.position.x + rect.size.x * i / 40.0
			pts.append(Vector2(x, sea_top + 14 + row * 22 + sin(i * 0.9 + t * (1.5 + row * 0.4) + row) * 4))
		c.draw_polyline(pts, Color(1, 1, 1, 0.5 - row * 0.12), 3.0, true)
	# Sand.
	var sand := PackedVector2Array()
	for i in 33:
		var x := rect.position.x + rect.size.x * i / 32.0
		sand.append(Vector2(x, gy + sin(i * 0.7) * 5 - 6))
	sand.append(rect.end)
	sand.append(Vector2(rect.position.x, rect.end.y))
	c.draw_colored_polygon(sand, Color("f7dd9d"))
	c.draw_polyline(sand.slice(0, 33), Art.OL, 6.0, true)
	for i in 10:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(gy + 20, rect.end.y))
		c.draw_circle(p, 3, Color("e5c27c"), true, -1.0, true)
	# Palm tree.
	var base := Vector2(rect.position.x + rect.size.x * 0.12, gy + 10)
	var trunk := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		trunk.append(base + Vector2(sin(k * 1.6) * 50, -k * 250))
	c.draw_polyline(trunk, Art.OL, 30.0, true)
	c.draw_polyline(trunk, Color("b67c45"), 22.0, true)
	for i in 8:
		c.draw_line(trunk[i] + Vector2(-10, 0), trunk[i] + Vector2(10, -4), Color("8d5b2f"), 3.0)
	var crown := trunk[8]
	for a in [-2.6, -1.9, -1.2, -0.5, 0.2]:
		var leaf := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			var dir := Vector2(cos(a + k * 0.6 * signf(a + 1.4)), sin(a) + k * 0.9)
			leaf.append(crown + dir.normalized() * k * 110 + Vector2(0, k * k * 30))
		c.draw_polyline(leaf, Art.OL, 24.0, true)
		c.draw_polyline(leaf, Color("4fbf4a"), 16.0, true)
	c.draw_circle(crown + Vector2(-8, 10), 10, Color("7a4b26"), true, -1.0, true)
	c.draw_circle(crown + Vector2(10, 12), 10, Color("7a4b26"), true, -1.0, true)
	# Umbrella.
	var u := Vector2(rect.position.x + rect.size.x * 0.88, gy + 30)
	outlined_rect(c, Rect2(u + Vector2(-4, -150), Vector2(8, 150)), Art.WHITE, 3, 3)
	var dome := Art.arc(u + Vector2(0, -140), 90, PI, TAU, 24)
	c.draw_polyline(Art.closed(dome), Art.OL, 8.0, true)
	c.draw_colored_polygon(dome, Art.RED)
	for k in 3:
		var seg := Art.arc(u + Vector2(0, -140), 90, PI + PI * (k * 2 + 1) / 6.0, PI + PI * (k * 2 + 2) / 6.0, 6)
		seg.append(u + Vector2(0, -140))
		c.draw_colored_polygon(seg, Art.WHITE)


static func _mall(c: CanvasItem, rect: Rect2, t: float, _rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("f7d2ea"), Color("ffeef7"))
	# Ceiling lights.
	for i in 6:
		var lx := rect.position.x + rect.size.x * (0.08 + i * 0.17)
		c.draw_line(Vector2(lx, rect.position.y), Vector2(lx, rect.position.y + 40), Art.OL, 3.0)
		var on := 0.75 + 0.25 * sin(t * 2.0 + i)
		glow(c, Vector2(lx, rect.position.y + 48), 12, Color(1, 0.95, 0.7, on), 3)
	# Shops.
	var colors := [Art.RED, Art.BLUE, Art.GREEN, Art.PURPLE]
	var shop_w := rect.size.x / 3.0
	for i in 3:
		var s := Rect2(rect.position.x + i * shop_w + 14, gy - 230, shop_w - 28, 230)
		outlined_rect(c, s, Color("fff8fc"), 6)
		outlined_rect(c, Rect2(s.position + Vector2(14, 60), Vector2(s.size.x - 28, s.size.y - 60)), Color("bfe8ff"), 4)
		c.draw_line(s.position + Vector2(40, 80), s.position + Vector2(70, 150), Color(1, 1, 1, 0.7), 8.0)
		var col: Color = colors[(i + 1) % colors.size()]
		var stripes := 8
		var aw := (s.size.x + 8) / stripes
		for k in stripes:
			var r := Rect2(s.position.x - 4 + k * aw, s.position.y + 12, aw, 34)
			c.draw_rect(r, col if k % 2 == 0 else Art.WHITE)
			c.draw_circle(Vector2(r.get_center().x, r.end.y), aw * 0.5, col if k % 2 == 0 else Art.WHITE, true, -1.0, true)
		c.draw_rect(Rect2(s.position.x - 4, s.position.y + 10, s.size.x + 8, 5), Art.OL)
		var shown: String = ["sneaker", "phone", "headphones"][i]
		Art.item(c, shown, Vector2(s.get_center().x + 20, s.end.y - 50), 0.8)
	# Floor tiles.
	c.draw_rect(Rect2(rect.position.x, gy, rect.size.x, rect.end.y - gy), Color("fff3e0"))
	var tile := 60.0
	var y := gy
	var row := 0
	while y < rect.end.y:
		var x := rect.position.x - (row % 2) * tile * 0.5
		while x < rect.end.x:
			c.draw_rect(Rect2(x, y, tile * 0.5, tile * 0.5), Color("f6c7dd"))
			x += tile
		y += tile * 0.5
		row += 1
	c.draw_rect(Rect2(rect.position.x, gy - 3, rect.size.x, 6), Art.OL)


static func _space(c: CanvasItem, rect: Rect2, t: float, rng: RandomNumberGenerator) -> void:
	var gy := ground_y(rect)
	grad(c, Rect2(rect.position, Vector2(rect.size.x, gy - rect.position.y)), Color("0b0a26"), Color("34205f"))
	for i in 70:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, gy))
		var tw := 0.5 + 0.5 * sin(t * (1.0 + rng.randf() * 2.0) + i)
		c.draw_circle(p, 0.8 + tw * 1.6, Color(1, 1, 1, 0.3 + tw * 0.7), true, -1.0, true)
	# Ringed planet.
	var planet := Vector2(rect.position.x + rect.size.x * 0.2, rect.position.y + rect.size.y * 0.2)
	c.draw_polyline(Art.closed(Art.ellipse(planet, 80, 18, -0.3)), Art.OL, 12.0, true)
	c.draw_circle(planet, 44, Art.OL, true, -1.0, true)
	c.draw_circle(planet, 40, Color("ff9a6b"), true, -1.0, true)
	c.draw_circle(planet + Vector2(-12, -12), 12, Color(1, 1, 1, 0.2), true, -1.0, true)
	var ring_front := Art.ellipse(planet, 80, 18, -0.3, 40).slice(0, 21)
	c.draw_polyline(ring_front, Color("ffd38a"), 6.0, true)
	# Earth.
	var earth := Vector2(rect.position.x + rect.size.x * 0.84, rect.position.y + rect.size.y * 0.14)
	glow(c, earth, 26, Color("4fa8ff"), 3)
	c.draw_circle(earth + Vector2(-6, -4), 9, Art.GREEN, true, -1.0, true)
	c.draw_circle(earth + Vector2(9, 8), 6, Art.GREEN, true, -1.0, true)
	# Moon ground with craters.
	var ground := PackedVector2Array()
	for i in 33:
		var x := rect.position.x + rect.size.x * i / 32.0
		ground.append(Vector2(x, gy + sin(i * 0.5) * 8 - 4))
	ground.append(rect.end)
	ground.append(Vector2(rect.position.x, rect.end.y))
	c.draw_colored_polygon(ground, Color("a8a6c0"))
	c.draw_polyline(ground.slice(0, 33), Art.OL, 6.0, true)
	for i in 8:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(gy + 25, rect.end.y - 10))
		var r := rng.randf_range(12, 30)
		c.draw_colored_polygon(Art.ellipse(p, r, r * 0.35), Color("8b88a8"))
		c.draw_colored_polygon(Art.ellipse(p + Vector2(0, 2), r * 0.8, r * 0.25), Color("7b7898"))
	# Glass dome base.
	var d := Vector2(rect.position.x + rect.size.x * 0.88, gy + 4)
	var dome := Art.arc(d, 90, PI, TAU, 24)
	c.draw_colored_polygon(dome, Color(0.7, 0.95, 1.0, 0.35))
	c.draw_polyline(dome, Art.OL, 6.0, true)
	c.draw_line(d + Vector2(-60, -66), d + Vector2(-40, -80), Color(1, 1, 1, 0.6), 5.0)
	glow(c, d + Vector2(10, -30), 8, Color("ffd66b"), 2)
