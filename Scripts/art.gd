class_name Art
extends RefCounted

# All art is drawn in code: flat colours with a thick dark outline.
#
# Shapes are put in groups. Within a group, all outlines are drawn first
# and then all fills, so overlapping shapes melt together into one
# outlined blob (like a cartoon drawing). Items and icons are built once
# and cached; drawing them is just a loop over the cached shapes.
#
# Item and icon art is designed in a box of about -40..40.

const OL := Color("2b1f35")
const W := 5.0

const WHITE := Color("ffffff")
const SHINE := Color(1, 1, 1, 0.55)
const GOLD := Color("ffcf3d")
const GOLD_DARK := Color("e09a1f")
const GOLD_LIGHT := Color("fff1a8")
const GRAY := Color("8e8aa0")
const GRAY_DARK := Color("4b4660")
const GRAY_LIGHT := Color("c9c6d6")
const PINK := Color("ff8fb1")
const RED := Color("ef4b4b")
const ORANGE := Color("ff9a3c")
const YELLOW := Color("ffd84a")
const GREEN := Color("6fcf4a")
const BLUE := Color("4fa8ff")
const PURPLE := Color("a46cff")
const BROWN := Color("9a6236")
const TAN := Color("e8b878")
const CREAM := Color("fff1d0")

static var _cache := {}
static var _font: Font


static func font() -> Font:
	if _font == null:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.8
		variation.spacing_glyph = 1
		_font = variation
	return _font


# --- Shape helpers ----------------------------------------------------------

static func C(p: Vector2, r: float, col: Color, ol := true) -> Dictionary:
	return {"k": 0, "p": p, "r": r, "col": col, "ol": ol}


static func P(pts: PackedVector2Array, col: Color, ol := true) -> Dictionary:
	return {"k": 1, "pts": clean(pts), "col": col, "ol": ol}


# Drops points that sit on top of each other; those break triangulation.
static func clean(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 0.04:
			out.append(p)
	while out.size() > 3 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.04:
		out.remove_at(out.size() - 1)
	return out


static func E(p: Vector2, rx: float, ry: float, col: Color, rot := 0.0, ol := true) -> Dictionary:
	return P(ellipse(p, rx, ry, rot), col, ol)


static func R(rect: Rect2, radius: float, col: Color, ol := true) -> Dictionary:
	return P(rrect(rect, radius), col, ol)


static func L(pts: PackedVector2Array, w: float, col: Color, ol := true, caps := true) -> Dictionary:
	return {"k": 2, "pts": pts, "w": w, "col": col, "ol": ol, "caps": caps}


static func V(pts: Array) -> PackedVector2Array:
	return PackedVector2Array(pts)


static func ellipse(p: Vector2, rx: float, ry: float, rot := 0.0, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func arc(center: Vector2, r: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


# Rounded rectangles are asked for many times per frame by the UI, so the
# points are remembered (the cache is cleared when it gets big).
static var _rrect_cache := {}


static func rrect(rect: Rect2, radius: float, n := 5) -> PackedVector2Array:
	var shape := int(roundf(radius * 2.0)) * 16 + n
	var by_shape: Dictionary = _rrect_cache.get(shape, {})
	var key := Rect2(rect.position.round(), rect.size.round())
	var hit = by_shape.get(key)
	if hit != null:
		return hit
	var pts := _make_rrect(rect, radius, n)
	if by_shape.size() > 500:
		by_shape.clear()
	by_shape[key] = pts
	_rrect_cache[shape] = by_shape
	return pts


static func _make_rrect(rect: Rect2, radius: float, n := 5) -> PackedVector2Array:
	rect = rect.abs()
	rect.size = rect.size.max(Vector2(2, 2))
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	if radius <= 0.5:
		return V([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var corners := [
		[Vector2(rect.end.x - radius, rect.position.y + radius), -PI / 2.0],
		[Vector2(rect.end.x - radius, rect.end.y - radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI / 2.0],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI],
	]
	for corner in corners:
		for i in n + 1:
			var a: float = corner[1] + PI / 2.0 * i / n
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * radius)
	return clean(pts)


static func star(p: Vector2, r_out: float, r_in: float, points := 5, rot := -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * i / points
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	return pts


static func blob(p: Vector2, r: float, wobble: float, waves: int, phase := 0.0, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var rr := r + wobble * sin(a * waves + phase)
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	return pts


static func mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


# --- Rendering ------------------------------------------------------------------

# silhouette: draw every fill in this colour (for not-yet-found items).
static func render(c: CanvasItem, groups: Array, w := W, silhouette := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	var outline := Color(OL, OL.a * alpha)
	for group in groups:
		for s in group:
			if s.ol:
				_outline(c, s, w, outline)
		for s in group:
			if silhouette.a > 0.0:
				if s.col.a > 0.9:
					_fill(c, s, Color(silhouette, silhouette.a * alpha))
			else:
				_fill(c, s, Color(s.col, s.col.a * alpha))


static func _outline(c: CanvasItem, s: Dictionary, w: float, col: Color) -> void:
	match s.k:
		0:
			c.draw_circle(s.p, s.r + w, col, true, -1.0, true)
		1:
			var pts: PackedVector2Array = s.pts
			c.draw_polyline(closed(pts), col, w * 2.0, true)
			if pts.size() < 24:
				for p in pts:
					c.draw_circle(p, w, col, true, -1.0, true)
		2:
			var pts: PackedVector2Array = s.pts
			c.draw_polyline(pts, col, s.w + w * 2.0, true)
			c.draw_circle(pts[0], s.w * 0.5 + w, col, true, -1.0, true)
			c.draw_circle(pts[pts.size() - 1], s.w * 0.5 + w, col, true, -1.0, true)


static func _fill(c: CanvasItem, s: Dictionary, col: Color) -> void:
	match s.k:
		0:
			c.draw_circle(s.p, s.r, col, true, -1.0, true)
		1:
			var pts: PackedVector2Array = s.pts
			c.draw_colored_polygon(pts, col)
			if not s.ol:
				c.draw_polyline(closed(pts), col, 1.2, true)
		2:
			var pts: PackedVector2Array = s.pts
			c.draw_polyline(pts, col, s.w, true)
			if s.get("caps", true):
				c.draw_circle(pts[0], s.w * 0.5, col, true, -1.0, true)
				c.draw_circle(pts[pts.size() - 1], s.w * 0.5, col, true, -1.0, true)


static func draw_groups(c: CanvasItem, groups: Array, pos: Vector2, scale: float,
		rot := 0.0, silhouette := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	c.draw_set_transform(pos, rot, Vector2(scale, scale))
	render(c, groups, W, silhouette, alpha)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func item(c: CanvasItem, id: String, pos: Vector2, scale: float, rot := 0.0,
		silhouette := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	if silhouette.a > 0.0:
		if Bake.draw(c, "itemsil_" + id, pos, Vector2(scale, scale), rot, Color(silhouette, alpha)):
			return
	elif Bake.draw(c, "item_" + id, pos, Vector2(scale, scale), rot, Color(1, 1, 1, alpha)):
		return
	var key := "item_" + id
	if not _cache.has(key):
		_cache[key] = item_shapes(id)
	draw_groups(c, _cache[key], pos, scale, rot, silhouette, alpha)


static func icon(c: CanvasItem, id: String, pos: Vector2, scale: float, rot := 0.0, alpha := 1.0) -> void:
	if Bake.draw(c, "icon_" + id, pos, Vector2(scale, scale), rot, Color(1, 1, 1, alpha)):
		return
	var key := "icon_" + id
	if not _cache.has(key):
		_cache[key] = icon_shapes(id)
	draw_groups(c, _cache[key], pos, scale, rot, Color(0, 0, 0, 0), alpha)


static func cached(key: String, builder: Callable) -> Array:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# Text with a thick outline, centred on pos.
static func text(c: CanvasItem, s: String, pos: Vector2, size: int, col := WHITE,
		align := HORIZONTAL_ALIGNMENT_CENTER, outline := -1, width := -1.0) -> void:
	var f := font()
	size = maxi(roundi(size / 2.0) * 2, 8)
	if outline < 0:
		outline = maxi(int(size * 0.32), 4)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	var baseline := pos.y + size * 0.36
	var p := Vector2(x, baseline)
	if outline > 0:
		c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, outline, Color(OL, col.a))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# A rounded panel with outline and a darker "bottom lip" (3D button look).
static func panel(c: CanvasItem, rect: Rect2, col: Color, radius := 18.0, lip := 6.0, w := 4.0) -> void:
	var outer := rect.grow(w)
	c.draw_colored_polygon(rrect(Rect2(outer.position + Vector2(0, lip), outer.size), radius + w), OL)
	c.draw_colored_polygon(rrect(outer, radius + w), OL)
	if lip > 0.0:
		c.draw_colored_polygon(rrect(Rect2(rect.position + Vector2(0, lip), rect.size), radius), col.darkened(0.28))
	c.draw_colored_polygon(rrect(rect, radius), col)
	if col.a < 1.0:
		return
	var shine := Rect2(rect.position + Vector2(radius * 0.6, 4), Vector2(rect.size.x - radius * 1.2, minf(rect.size.y * 0.3, 14)))
	if shine.size.x > 4:
		c.draw_colored_polygon(rrect(shine, shine.size.y * 0.5), Color(1, 1, 1, 0.18))


static func rays(c: CanvasItem, pos: Vector2, r: float, count: int, rot: float, col: Color) -> void:
	for i in count:
		var a := rot + TAU * i / count
		var w := PI / count * 0.55
		c.draw_colored_polygon(V([pos, pos + Vector2(cos(a - w), sin(a - w)) * r, pos + Vector2(cos(a + w), sin(a + w)) * r]), col)


# A filled ellipse without building new points every frame.
static func shadow(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	if Bake.draw(c, "fx_dot", center, Vector2(rx, ry) / Bake.FX_RADIUS, 0.0, col):
		return
	var unit: PackedVector2Array = cached_points("unit_circle", func() -> PackedVector2Array: return ellipse(Vector2.ZERO, 1.0, 1.0, 0.0, 24))
	c.draw_set_transform(center, 0.0, Vector2(rx, ry))
	c.draw_colored_polygon(unit, col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static var _points_cache := {}


static func cached_points(key: String, builder: Callable) -> PackedVector2Array:
	if not _points_cache.has(key):
		_points_cache[key] = builder.call()
	return _points_cache[key]


# A filled circle (baked sprite when possible).
static func dot(c: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	if Bake.draw(c, "fx_dot", pos, Vector2.ONE * (r / Bake.FX_RADIUS), 0.0, col):
		return
	c.draw_circle(pos, r, col, true, -1.0, true)


# A soft glow with a solid core of radius r (like Scenery.glow).
static func glow(c: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	if Bake.draw(c, "fx_glow", pos, Vector2.ONE * (r * 2.2 / Bake.FX_RADIUS), 0.0, Color(col, col.a * 0.9)):
		Bake.draw(c, "fx_dot", pos, Vector2.ONE * (r / Bake.FX_RADIUS), 0.0, col)
		return
	Scenery.glow(c, pos, r, col, 3)


static func sparkle(c: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	if Bake.draw(c, "fx_spark", pos, Vector2.ONE * (r / Bake.FX_RADIUS), 0.0, col):
		return
	c.draw_colored_polygon(star(pos, r, r * 0.28, 4, 0.0), col)


# --- Items ----------------------------------------------------------------------

static func item_shapes(id: String) -> Array:
	match id:
		"banana":
			var pts := arc(Vector2(0, -24), 38, deg_to_rad(15), deg_to_rad(165), 20)
			pts.append_array(arc(Vector2(0, -62), 60.3, deg_to_rad(127.5), deg_to_rad(52.5), 16))
			return [
				[P(pts, YELLOW), C(Vector2(-37, -13), 5, BROWN), C(Vector2(37, -13), 4, BROWN)],
				[C(Vector2(-12, 6), 3.5, BROWN, false), C(Vector2(10, 8), 2.5, BROWN, false), C(Vector2(-2, 10), 2, BROWN, false),
					L(arc(Vector2(0, -24), 31, deg_to_rad(110), deg_to_rad(60), 8), 4, Color("fff3a0"), false)],
			]
		"apple":
			var core := PackedVector2Array()
			for i in 11:
				var y := lerpf(-22, 22, i / 10.0)
				core.append(Vector2(8 + 8 * pow(absf(y) / 22.0, 2), y))
			for i in 11:
				var y := lerpf(22, -22, i / 10.0)
				core.append(Vector2(-8 - 8 * pow(absf(y) / 22.0, 2), y))
			return [
				[E(Vector2(0, -24), 22, 13, RED), E(Vector2(0, 24), 21, 12, RED), P(core, CREAM)],
				[L(V([Vector2(0, -34), Vector2(3, -44)]), 4, BROWN), E(Vector2(11, -42), 8, 4, GREEN, -0.4)],
				[E(Vector2(-3, -3), 2.5, 4, BROWN, 0.3, false), E(Vector2(3, 5), 2.5, 4, BROWN, -0.3, false),
					E(Vector2(-9, -28), 5, 3, SHINE, -0.3, false)],
			]
		"fishbone":
			var bone := Color("f3eee4")
			var g := [E(Vector2(22, 0), 16, 14, bone), L(V([Vector2(-26, 0), Vector2(12, 0)]), 5, bone),
				P(V([Vector2(-24, 0), Vector2(-40, -14), Vector2(-35, 0), Vector2(-40, 14)]), bone)]
			for x in [-14, -3, 8]:
				g.append(L(V([Vector2(x - 5, -15), Vector2(x + 2, 0), Vector2(x - 5, 15)]), 4, bone))
			return [g, [L(V([Vector2(23, -6), Vector2(29, 0)]), 2.5, OL, false), L(V([Vector2(29, -6), Vector2(23, 0)]), 2.5, OL, false),
				L(V([Vector2(30, 6), Vector2(36, 5)]), 2.5, OL, false)]]
		"duck":
			return [
				[E(Vector2(-4, 12), 30, 20, YELLOW), C(Vector2(14, -14), 17, YELLOW),
					P(V([Vector2(-28, 2), Vector2(-40, -12), Vector2(-24, -2)]), YELLOW)],
				[E(Vector2(33, -9), 11, 5, ORANGE, 0.1)],
				[E(Vector2(-8, 12), 14, 9, Color("ffbf2e"), -0.3)],
				[C(Vector2(18, -18), 3.5, OL, false), C(Vector2(19, -19.5), 1.3, WHITE, false),
					E(Vector2(6, -24), 6, 3, SHINE, -0.4, false), E(Vector2(-14, 2), 8, 3, SHINE, -0.2, false)],
			]
		"ring":
			return [
				[L(closed(ellipse(Vector2(0, 10), 24, 22, 0.0, 28)), 9, GOLD)],
				[R(Rect2(-9, -14, 18, 8), 2, GOLD_DARK)],
				[P(V([Vector2(-12, -32), Vector2(12, -32), Vector2(19, -23), Vector2(0, -7), Vector2(-19, -23)]), Color("7fe6ff"))],
				[L(V([Vector2(-19, -23), Vector2(19, -23)]), 2, Color("c8f6ff"), false), L(V([Vector2(-5, -32), Vector2(-8, -23), Vector2(0, -8)]), 2, Color("c8f6ff"), false),
					L(arc(Vector2(0, 10), 24, deg_to_rad(200), deg_to_rad(250), 6), 3, GOLD_LIGHT, false),
					P(star(Vector2(10, -28), 7, 2, 4, 0.0), WHITE, false)],
			]
		"icecream":
			var cone := [P(V([Vector2(-17, -4), Vector2(17, -4), Vector2(0, 38)]), TAN)]
			var lines := []
			for x in [-8, 2, 12]:
				lines.append(L(V([Vector2(x - 6, -2), Vector2(x - 14 * 0.5 + 9, 20)]), 1.8, Color("c48a4a"), false))
			return [cone, lines,
				[C(Vector2(0, -14), 20, PINK), C(Vector2(-13, -2), 7, PINK), C(Vector2(9, 0), 6, PINK), C(Vector2(-2, 1), 5, PINK)],
				[L(V([Vector2(4, -32), Vector2(9, -42)]), 2.5, BROWN), C(Vector2(4, -34), 6, RED)],
				[L(V([Vector2(-8, -18), Vector2(-4, -20)]), 2.5, BLUE, false), L(V([Vector2(6, -12), Vector2(10, -9)]), 2.5, YELLOW, false),
					L(V([Vector2(-4, -6), Vector2(-1, -9)]), 2.5, GREEN, false), E(Vector2(-8, -24), 5, 3, SHINE, -0.4, false)],
			]
		"sock":
			return [
				[R(Rect2(-18, -38, 26, 48), 8, Color("f4f1ea")), R(Rect2(-18, 0, 46, 22), 11, Color("f4f1ea"))],
				[R(Rect2(-18, -32, 26, 6), 0, RED, false), R(Rect2(-18, -22, 26, 6), 0, BLUE, false),
					C(Vector2(22, 11), 4, Color("d9d3c4"), false), C(Vector2(-4, -6), 4, OL, false)],
				[L(V([Vector2(16, -26), Vector2(20, -32), Vector2(16, -38)]), 3, GREEN, false),
					L(V([Vector2(25, -14), Vector2(29, -20), Vector2(25, -26)]), 3, GREEN, false)],
			]
		"frisbee":
			return [
				[E(Vector2(0, 0), 36, 15, Color("ff6f91"), -0.2)],
				[E(Vector2(-1, -2), 22, 8, Color("ffa4bc"), -0.2, false), L(arc(Vector2(0, 0), 30, deg_to_rad(20), deg_to_rad(160), 10), 2.5, Color("c94a6c"), false),
					E(Vector2(-14, -4), 6, 2.5, SHINE, -0.2, false)],
			]
		"teddy":
			var fur := Color("b97a4a")
			return [
				[C(Vector2(-18, -26), 9, fur), C(Vector2(18, -26), 9, fur), C(Vector2(0, -12), 20, fur), E(Vector2(0, 20), 20, 18, fur),
					C(Vector2(-21, 14), 8, fur), C(Vector2(21, 14), 8, fur), C(Vector2(-12, 34), 8, fur), C(Vector2(12, 34), 8, fur)],
				[C(Vector2(-18, -26), 4.5, TAN, false), C(Vector2(18, -26), 4.5, TAN, false), E(Vector2(0, 22), 11, 10, TAN, 0.0, false),
					E(Vector2(0, -5), 9, 7, TAN, 0.0, false), E(Vector2(0, -8), 4, 3, OL, 0.0, false),
					C(Vector2(-7, -15), 3, OL, false), C(Vector2(7, -15), 3, OL, false)],
				[P(V([Vector2(0, 6), Vector2(-10, 0), Vector2(-10, 12)]), BLUE), P(V([Vector2(0, 6), Vector2(10, 0), Vector2(10, 12)]), BLUE)],
				[L(V([Vector2(12, 18), Vector2(18, 24)]), 2, OL, false), L(V([Vector2(18, 18), Vector2(12, 24)]), 2, OL, false)],
			]
		"acorn":
			var hatch := []
			for i in 5:
				hatch.append(L(V([Vector2(-20 + i * 10, -22), Vector2(-24 + i * 10, -6)]), 2, GOLD_DARK.darkened(0.2), false))
			return [
				[E(Vector2(0, 10), 20, 25, GOLD)],
				[E(Vector2(0, -14), 27, 13, GOLD_DARK), L(V([Vector2(0, -26), Vector2(4, -38)]), 5, GOLD_DARK)],
				hatch,
				[E(Vector2(-8, 6), 5, 10, Color(1, 1, 1, 0.45), 0.2, false), P(star(Vector2(14, 22), 7, 2, 4, 0.0), WHITE, false)],
			]
		"pizza":
			return [
				[P(V([Vector2(-30, -24), Vector2(30, -24), Vector2(0, 36)]), Color("ffd35a")), L(V([Vector2(-32, -27), Vector2(32, -27)]), 11, Color("d98c3f"))],
				[C(Vector2(-9, -11), 7, RED, false), C(Vector2(10, -9), 6, RED, false), C(Vector2(0, 11), 5.5, RED, false),
					C(Vector2(-7, -13), 2, Color("ff9a9a"), false), C(Vector2(12, -11), 2, Color("ff9a9a"), false),
					C(Vector2(-2, -1), 2.5, GREEN, false), C(Vector2(14, 4), 2, GREEN, false)],
			]
		"donut":
			var sprinkles := []
			var colors := [RED, BLUE, YELLOW, GREEN, WHITE, PURPLE]
			for i in 10:
				var a := TAU * i / 10.0 + 0.3
				var p := Vector2(cos(a), sin(a)) * (20 + (i % 2) * 6)
				sprinkles.append(L(V([p, p + Vector2(cos(a + 1.2), sin(a + 1.2)) * 5]), 2.6, colors[i % colors.size()], false))
			return [
				[L(closed(ellipse(Vector2.ZERO, 22, 22, 0.0, 30)), 22, TAN)],
				[L(closed(blob(Vector2(0, -1), 22, 2, 7)), 16, PINK, false)],
				sprinkles,
			]
		"burger":
			return [
				[R(Rect2(-32, 14, 64, 14), 7, Color("e0a052"))],
				[R(Rect2(-34, 2, 68, 14), 7, Color("7a4527"))],
				[P(V([Vector2(-32, 0), Vector2(32, 0), Vector2(26, 10), Vector2(16, 4), Vector2(4, 12), Vector2(-8, 4), Vector2(-20, 10)]), YELLOW)],
				[L(V([Vector2(-34, -4), Vector2(-24, 0), Vector2(-14, -4), Vector2(-4, 0), Vector2(6, -4), Vector2(16, 0), Vector2(26, -4), Vector2(34, 0)]), 6, GREEN)],
				[P(arc(Vector2(0, -4), 33, PI, TAU, 18), Color("eaa856"))],
				[E(Vector2(-12, -20), 3, 1.8, CREAM, 0.3, false), E(Vector2(4, -26), 3, 1.8, CREAM, -0.3, false), E(Vector2(16, -16), 3, 1.8, CREAM, 0.4, false),
					E(Vector2(-4, -14), 3, 1.8, CREAM, 0.0, false), E(Vector2(-18, -28), 6, 3, SHINE, -0.5, false)],
			]
		"gamepad":
			var body := Color("6b6fd6")
			return [
				[R(Rect2(-36, -16, 72, 30), 15, body), C(Vector2(-25, 10), 14, body), C(Vector2(25, 10), 14, body)],
				[R(Rect2(-29, -6, 18, 6), 2, OL, false), R(Rect2(-23, -12, 6, 18), 2, OL, false),
					C(Vector2(20, -10), 4.5, RED, false), C(Vector2(29, -3), 4.5, YELLOW, false), C(Vector2(11, -3), 4.5, BLUE, false),
					C(Vector2(20, 4), 4.5, GREEN, false), E(Vector2(-14, -11), 8, 2.5, Color(1, 1, 1, 0.3), 0.0, false)],
			]
		"crown":
			return [
				[P(V([Vector2(-32, 20), Vector2(-32, -14), Vector2(-17, 2), Vector2(0, -25), Vector2(17, 2), Vector2(32, -14), Vector2(32, 20)]), GOLD),
					C(Vector2(-32, -17), 5, GOLD), C(Vector2(0, -28), 5, GOLD), C(Vector2(32, -17), 5, GOLD)],
				[R(Rect2(-32, 12, 64, 8), 0, GOLD_DARK, false)],
				[C(Vector2(0, 2), 6, RED)], [E(Vector2(-19, 6), 4, 5, BLUE)], [E(Vector2(19, 6), 4, 5, GREEN)],
				[E(Vector2(-22, -6), 3, 8, Color(1, 1, 1, 0.4), 0.5, false), P(star(Vector2(-12, -14), 6, 1.8, 4, 0.0), WHITE, false)],
			]
		"shell":
			var edge := PackedVector2Array()
			for i in 29:
				var a := lerpf(PI * 1.05, PI * 1.95, i / 28.0)
				var r := 34.0 + 2.5 * sin(i * PI / 2.0)
				edge.append(Vector2(0, 16) + Vector2(cos(a), sin(a)) * r)
			edge.append(Vector2(9, 24))
			edge.append(Vector2(-9, 24))
			var ridges := []
			for i in 6:
				var a := lerpf(PI * 1.15, PI * 1.85, i / 5.0)
				ridges.append(L(V([Vector2(0, 18), Vector2(0, 16) + Vector2(cos(a), sin(a)) * 30]), 2.5, Color("e86f8f"), false))
			return [[P(edge, Color("ffb3c4"))], ridges, [E(Vector2(-12, -6), 4, 7, SHINE, 0.5, false)]]
		"flipflop":
			return [
				[E(Vector2(0, 0), 18, 36, Color("38b6ff"), 0.25)],
				[E(Vector2(0, 0), 12, 30, Color("8fd8ff"), 0.25, false)],
				[L(V([Vector2(-12, -2), Vector2(4, -20), Vector2(14, 4)]), 6, YELLOW)],
				[C(Vector2(4, -20), 4, ORANGE)],
			]
		"bottle":
			var glass := Color(0.55, 0.9, 0.75, 1.0)
			return [
				[R(Rect2(-15, -12, 30, 46), 11, glass), R(Rect2(-7, -32, 14, 24), 4, glass)],
				[R(Rect2(-8, -42, 16, 11), 3, TAN)],
				[R(Rect2(-9, -2, 18, 28), 3, Color("fff6dc"))],
				[L(V([Vector2(-5, 4), Vector2(5, 4)]), 2, BROWN, false), L(V([Vector2(-5, 10), Vector2(5, 10)]), 2, BROWN, false),
					L(V([Vector2(-5, 16), Vector2(2, 16)]), 2, BROWN, false), E(Vector2(-9, -6), 2.5, 10, SHINE, 0.0, false)],
			]
		"chest":
			var wood := Color("a8642f")
			return [
				[C(Vector2(-14, -27), 8, GOLD), C(Vector2(2, -31), 8, GOLD), C(Vector2(16, -26), 8, GOLD)],
				[R(Rect2(-33, -4, 66, 34), 5, wood)],
				[R(Rect2(-33, -26, 66, 24), 11, Color("bf7a3e"))],
				[R(Rect2(-24, -26, 8, 56), 0, GOLD_DARK, false), R(Rect2(16, -26, 8, 56), 0, GOLD_DARK, false)],
				[R(Rect2(-7, -9, 14, 16), 3, GOLD)],
				[C(Vector2(0, -2), 2.5, OL, false), P(star(Vector2(-22, -32), 7, 2, 4, 0.0), WHITE, false)],
			]
		"pearl":
			var bowl := arc(Vector2(0, 2), 36, 0.0, PI, 18)
			return [
				[E(Vector2(0, -12), 34, 15, Color("e98aa6"), 0.12)],
				[P(bowl, Color("ffaec4"))],
				[C(Vector2(0, -4), 16, Color("fbf6ff"))],
				[C(Vector2(-6, -9), 5, WHITE, false), E(Vector2(0, -4), 12, 12, Color(0.8, 0.85, 1.0, 0.0), 0.0, false),
					L(arc(Vector2(0, 2), 26, 0.4, PI - 0.4, 10), 2.5, Color("e98aa6"), false), P(star(Vector2(18, -22), 8, 2, 4, 0.0), WHITE, false)],
			]
		"can":
			return [
				[R(Rect2(-18, -30, 36, 62), 6, RED)],
				[E(Vector2(0, -30), 18, 5, GRAY_LIGHT)],
				[L(V([Vector2(-18, 0), Vector2(-8, -6), Vector2(4, 4), Vector2(18, -2)]), 6, WHITE, false),
					R(Rect2(-3, -34, 8, 4), 2, GRAY, false), R(Rect2(-12, -20, 5, 44), 2, Color(1, 1, 1, 0.3), false),
					L(V([Vector2(6, 12), Vector2(12, 18)]), 2.5, Color("a32b2b"), false)],
			]
		"sneaker":
			var upper := V([Vector2(-34, 10), Vector2(-34, -14), Vector2(-22, -20), Vector2(-8, -10), Vector2(10, -6), Vector2(28, 0), Vector2(36, 10)])
			return [
				[P(upper, Color("4f7dff"))],
				[R(Rect2(-37, 8, 75, 12), 6, WHITE)],
				[P(V([Vector2(-20, 6), Vector2(4, -4), Vector2(20, 6)]), ORANGE, false),
					L(V([Vector2(-14, -12), Vector2(-6, -4)]), 2.5, WHITE, false), L(V([Vector2(-8, -14), Vector2(0, -6)]), 2.5, WHITE, false),
					L(V([Vector2(-2, -12), Vector2(6, -4)]), 2.5, WHITE, false), R(Rect2(-36, 14, 73, 3), 0, GRAY_LIGHT, false)],
			]
		"phone":
			return [
				[R(Rect2(-20, -36, 40, 72), 8, Color("3a3550"))],
				[R(Rect2(-15, -29, 30, 54), 3, Color("5fd0ff"), false), R(Rect2(-6, -33, 12, 3), 1.5, Color("1e1a2c"), false)],
				[L(V([Vector2(-15, -12), Vector2(-2, -4), Vector2(6, -18), Vector2(15, -10)]), 2, WHITE, false),
					L(V([Vector2(-2, -4), Vector2(2, 10)]), 2, WHITE, false), C(Vector2(0, 30), 2.5, GRAY, false),
					E(Vector2(-8, -20), 3, 7, SHINE, 0.3, false)],
			]
		"headphones":
			var cup := Color("ff6fb5")
			return [
				[L(arc(Vector2(0, 2), 28, PI * 1.02, PI * 1.98, 18), 7, Color("6b4fd6"))],
				[R(Rect2(-40, -4, 17, 30), 8, cup)], [R(Rect2(23, -4, 17, 30), 8, cup)],
				[R(Rect2(-26, 0, 7, 22), 3, Color("3a3550"), false), R(Rect2(19, 0, 7, 22), 3, Color("3a3550"), false),
					E(Vector2(-34, 2), 2.5, 6, SHINE, 0.0, false), E(Vector2(29, 2), 2.5, 6, SHINE, 0.0, false)],
			]
		"diamond":
			var light := Color("c9f6ff")
			return [
				[P(V([Vector2(-32, -10), Vector2(-17, -27), Vector2(17, -27), Vector2(32, -10), Vector2(0, 32)]), Color("6fe0ff"))],
				[L(V([Vector2(-32, -10), Vector2(32, -10)]), 2.5, light, false), L(V([Vector2(-17, -27), Vector2(-10, -10), Vector2(0, 32)]), 2.5, light, false),
					L(V([Vector2(17, -27), Vector2(10, -10), Vector2(0, 32)]), 2.5, light, false), L(V([Vector2(0, -27), Vector2(-10, -10)]), 2, light, false),
					L(V([Vector2(0, -27), Vector2(10, -10)]), 2, light, false), P(V([Vector2(-17, -27), Vector2(-4, -27), Vector2(-14, -12), Vector2(-26, -12)]), Color(1, 1, 1, 0.5), false),
					P(star(Vector2(22, -26), 9, 2.4, 4, 0.0), WHITE, false), P(star(Vector2(-24, 10), 6, 1.6, 4, 0.0), WHITE, false)],
			]
		"moonrock":
			return [
				[P(blob(Vector2.ZERO, 30, 4, 5, 0.7), Color("a7a3bd"))],
				[E(Vector2(-10, -8), 8, 6, Color("8a85a3"), 0.2, false), E(Vector2(12, 6), 6, 5, Color("8a85a3"), 0.0, false),
					E(Vector2(-4, 14), 4, 3, Color("8a85a3"), 0.0, false), E(Vector2(-12, -16), 6, 3, SHINE, -0.4, false)],
			]
		"goo":
			var goo := Color("7dff5a")
			var shape := PackedVector2Array()
			for i in 25:
				var a := lerpf(PI, TAU, i / 24.0)
				shape.append(Vector2(cos(a) * 32, sin(a) * 30 + 14) + Vector2(0, 2 * sin(i * 1.3)))
			shape.append(Vector2(34, 28))
			shape.append(Vector2(-34, 28))
			return [
				[P(shape, goo), L(V([Vector2(-10, -14), Vector2(-14, -30)]), 4, goo), L(V([Vector2(10, -14), Vector2(14, -30)]), 4, goo)],
				[C(Vector2(-14, -32), 7, WHITE), C(Vector2(14, -32), 7, WHITE)],
				[C(Vector2(-13, -31), 3.5, OL, false), C(Vector2(15, -31), 3.5, OL, false), L(arc(Vector2(0, 8), 10, 0.3, PI - 0.3, 8), 3, Color("2f9a2a"), false),
					E(Vector2(-18, -2), 6, 4, SHINE, -0.4, false), C(Vector2(20, 18), 3, Color("b5ff9e"), false)],
			]
		"raygun":
			return [
				[P(V([Vector2(-22, 4), Vector2(-8, 4), Vector2(-12, 30), Vector2(-26, 30)]), Color("3a3550"))],
				[R(Rect2(8, -7, 22, 12), 4, GRAY_LIGHT)],
				[R(Rect2(-32, -14, 44, 22), 11, Color("3fd1b8"))],
				[C(Vector2(34, -1), 6, Color("b5ff5a"))],
				[L(V([Vector2(14, -7), Vector2(14, 5)]), 2.5, GRAY, false), L(V([Vector2(21, -7), Vector2(21, 5)]), 2.5, GRAY, false),
					C(Vector2(-14, -3), 4, YELLOW, false), E(Vector2(-18, -9), 9, 2.5, SHINE, 0.0, false)],
			]
		"satellite":
			var panel_col := Color("4f7dff")
			var grid := []
			for x in [-33, -26, 26, 33]:
				grid.append(L(V([Vector2(x, -8), Vector2(x, 8)]), 1.6, Color("9fc0ff"), false))
			return [
				[L(V([Vector2(-20, 0), Vector2(20, 0)]), 3, GRAY)],
				[R(Rect2(-40, -9, 22, 18), 2, panel_col)], [R(Rect2(18, -9, 22, 18), 2, panel_col)],
				grid,
				[R(Rect2(-12, -12, 24, 24), 4, GRAY_LIGHT)],
				[L(V([Vector2(0, -12), Vector2(0, -28)]), 2.5, GRAY), C(Vector2(0, -30), 4, RED)],
				[C(Vector2(-4, -4), 3, BLUE, false), E(Vector2(-6, -8), 4, 2, SHINE, 0.0, false)],
			]
		"star":
			return [
				[P(star(Vector2(0, 2), 38, 17, 5), GOLD)],
				[C(Vector2(-7, -1), 3.5, OL, false), C(Vector2(7, -1), 3.5, OL, false), L(arc(Vector2(0, 5), 6, 0.3, PI - 0.3, 8), 2.5, OL, false),
					C(Vector2(-12, 6), 3, Color(1, 0.5, 0.5, 0.6), false), C(Vector2(12, 6), 3, Color(1, 0.5, 0.5, 0.6), false),
					E(Vector2(-8, -16), 3, 6, SHINE, 0.4, false)],
			]
	return [[C(Vector2.ZERO, 20, GRAY)]]


# --- Icons ----------------------------------------------------------------------

static func paw_shapes(col: Color, claws: bool) -> Array:
	var g := [E(Vector2(0, 12), 20, 17, col)]
	var toes := [Vector2(-22, -6), Vector2(-9, -20), Vector2(9, -20), Vector2(22, -6)]
	var claw_group := []
	for t in toes:
		g.append(E(t, 8, 10, col, t.x * 0.02))
		if claws:
			var tip: Vector2 = t * 1.45 + Vector2(0, -6)
			claw_group.append(P(V([t + Vector2(-4, -6), tip, t + Vector2(4, -6)]), WHITE))
	if claws:
		return [claw_group, g, [E(Vector2(-6, 6), 7, 4, SHINE, -0.3, false)]]
	return [g, [E(Vector2(-6, 6), 7, 4, SHINE, -0.3, false)]]


static func icon_shapes(id: String) -> Array:
	match id:
		"coin":
			var paw := []
			for t in [Vector2(-9, -5), Vector2(-3, -11), Vector2(4, -11), Vector2(10, -5)]:
				paw.append(C(t, 4, GOLD_DARK, false))
			paw.append(E(Vector2(0, 5), 9, 8, GOLD_DARK, 0.0, false))
			return [[C(Vector2.ZERO, 32, GOLD)], [C(Vector2.ZERO, 24, Color("ffe066"), false)], paw,
				[E(Vector2(-13, -16), 7, 4, SHINE, -0.6, false)]]
		"claws":
			return paw_shapes(GRAY, true)
		"paws":
			var a := paw_shapes(Color("b6a3d6"), false)
			var out := []
			for group in a:
				var moved := []
				for s in group:
					moved.append(_offset(s, Vector2(-12, 8), 0.75))
				out.append(moved)
			for group in paw_shapes(GRAY, false):
				var moved := []
				for s in group:
					moved.append(_offset(s, Vector2(10, -6), 0.8))
				out.append(moved)
			return out
		"tail":
			var curve := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				curve.append(Vector2(lerpf(-30, 26, t), 22 - sin(t * PI) * 30 - t * 14))
			var bands := []
			for j in [2, 5, 8, 11]:
				bands.append(L(curve.slice(j, j + 2), 20, OL, false, false))
			return [[L(curve, 20, GRAY)], bands, [C(curve[12], 8, OL, false)]]
		"eyes":
			return [
				[P(_almond(36, 22), WHITE)],
				[C(Vector2(0, 0), 15, Color("4fb4ff"), false)],
				[C(Vector2(0, 0), 8, OL, false), C(Vector2(-5, -5), 4, WHITE, false)],
				[P(star(Vector2(26, -24), 12, 3, 4, 0.0), YELLOW)],
			]
		"glove":
			var groups := paw_shapes(GOLD, false)
			groups.append([P(star(Vector2(24, -26), 10, 2.6, 4, 0.0), WHITE, false), P(star(Vector2(-26, 22), 7, 2, 4, 0.0), WHITE, false)])
			return groups
		"rage":
			var flame := PackedVector2Array()
			for i in 21:
				var t := i / 20.0
				var a := lerpf(-PI * 0.5, PI * 1.5, t)
				var r := 26.0 + (10.0 if i % 4 == 0 else 0.0)
				var p := Vector2(cos(a) * r * 0.8, sin(a) * r)
				if p.y < 0:
					p.y *= 1.4
				flame.append(p + Vector2(0, 8))
			return [[P(flame, Color("ff5b3a"))], [E(Vector2(0, 16), 13, 16, YELLOW, 0.0, false)],
				[C(Vector2(-6, 12), 3, OL, false), C(Vector2(6, 12), 3, OL, false),
					L(V([Vector2(-11, 5), Vector2(-3, 9)]), 2.5, OL, false), L(V([Vector2(11, 5), Vector2(3, 9)]), 2.5, OL, false)]]
		"music":
			return [[C(Vector2(-14, 20), 11, PURPLE), C(Vector2(18, 12), 11, PURPLE),
				L(V([Vector2(-4, 20), Vector2(-4, -22)]), 6, PURPLE), L(V([Vector2(28, 12), Vector2(28, -30)]), 6, PURPLE),
				L(V([Vector2(-4, -22), Vector2(28, -30)]), 9, PURPLE)]]
		"sound":
			return [[R(Rect2(-30, -12, 18, 24), 3, BLUE), P(V([Vector2(-14, -12), Vector2(4, -28), Vector2(4, 28), Vector2(-14, 12)]), BLUE)],
				[L(arc(Vector2(4, 0), 14, -0.8, 0.8, 8), 5, BLUE)], [L(arc(Vector2(4, 0), 26, -0.8, 0.8, 10), 5, BLUE)]]
		"book":
			return [
				[R(Rect2(-30, -32, 60, 66), 8, Color("6b4fd6"))],
				[R(Rect2(-22, -24, 44, 50), 4, Color("8a6ff0"), false), R(Rect2(-30, 22, 60, 10), 4, Color("fff1d0"))],
				[P(star(Vector2(0, -2), 15, 6.5, 5), GOLD)],
			]
		"cap":
			return [
				[P(blob(Vector2.ZERO, 31, 3.5, 14, 0.0, 56), GOLD)],
				[C(Vector2.ZERO, 22, Color("ffe066"), false)],
				[P(star(Vector2(0, 1), 15, 6.5, 5), GOLD_DARK, false)],
				[E(Vector2(-12, -14), 6, 3, SHINE, -0.6, false)],
			]
		"cart":
			var basket := V([Vector2(-34, -22), Vector2(30, -22), Vector2(22, 10), Vector2(-26, 10)])
			return [
				[L(V([Vector2(30, -22), Vector2(36, -34), Vector2(44, -34)]), 6, GRAY_DARK)],
				[C(Vector2(-12, -26), 12, GOLD), C(Vector2(6, -30), 10, Color("ff6f91")), C(Vector2(20, -24), 9, BLUE)],
				[P(basket, WHITE)],
				[L(V([Vector2(-18, -20), Vector2(-14, 8)]), 3, GRAY_LIGHT, false, false), L(V([Vector2(-2, -20), Vector2(-1, 8)]), 3, GRAY_LIGHT, false, false),
					L(V([Vector2(14, -20), Vector2(12, 8)]), 3, GRAY_LIGHT, false, false), L(V([Vector2(-30, -6), Vector2(26, -6)]), 3, GRAY_LIGHT, false, false)],
				[L(V([Vector2(-26, 10), Vector2(-28, 20), Vector2(24, 20)]), 5, GRAY_DARK)],
				[C(Vector2(-18, 28), 7, GRAY_DARK), C(Vector2(16, 28), 7, GRAY_DARK)],
			]
		"lock":
			return [[L(arc(Vector2(0, -6), 14, PI, TAU, 12), 7, GRAY)], [R(Rect2(-22, -6, 44, 36), 8, GOLD_DARK)], [C(Vector2(0, 10), 4, OL, false)]]
		"close":
			return [[L(V([Vector2(-16, -16), Vector2(16, 16)]), 9, WHITE), L(V([Vector2(16, -16), Vector2(-16, 16)]), 9, WHITE)]]
		"arrow":
			return [[P(V([Vector2(-26, -10), Vector2(2, -10), Vector2(2, -26), Vector2(30, 0), Vector2(2, 26), Vector2(2, 10), Vector2(-26, 10)]), GREEN)]]
		"star":
			return [[P(star(Vector2(0, 2), 34, 15, 5), GOLD)], [E(Vector2(-8, -12), 4, 7, SHINE, 0.4, false)]]
		"golden":
			return [
				[P(V([Vector2(-26, -8), Vector2(26, -8), Vector2(20, 34), Vector2(-20, 34)]), GOLD)],
				[E(Vector2(0, -12), 30, 9, GOLD_LIGHT)],
				[L(V([Vector2(-6, -22), Vector2(6, -22)]), 5, GOLD_DARK)],
				[L(V([Vector2(-10, -2), Vector2(-8, 28)]), 2.5, GOLD_DARK, false), L(V([Vector2(0, -2), Vector2(0, 28)]), 2.5, GOLD_DARK, false),
					L(V([Vector2(10, -2), Vector2(8, 28)]), 2.5, GOLD_DARK, false), E(Vector2(-14, 8), 3, 10, SHINE, 0.1, false)],
			]
	return [[C(Vector2.ZERO, 20, GRAY)]]


static func _almond(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry * (0.55 + 0.45 * absf(sin(a)))))
	return pts


static func _offset(s: Dictionary, offset: Vector2, scale: float) -> Dictionary:
	var out := s.duplicate()
	match s.k:
		0:
			out.p = s.p * scale + offset
			out.r = s.r * scale
		_:
			var pts := PackedVector2Array()
			for p in s.pts:
				pts.append(p * scale + offset)
			out.pts = pts
			if s.k == 2:
				out.w = s.w * scale
	return out
