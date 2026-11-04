extends Node2D

# All "juice" in one node: flying items, floating numbers, sparkles,
# dust, coins that fly to the counter, the big rare-item showcase,
# banners, screen flash and shake. Everything is drawn in _draw, which
# is much cheaper than a node per particle on the web.

signal coin_arrived

const MAX_ITEMS := 10
const MAX_TEXTS := 8
const MAX_PARTS := 140
const GRAVITY := 1900.0

var area := Rect2(0, 0, 800, 600)
var coin_target := Vector2(100, 60)
var shake := 0.0
var flash := 0.0
var flash_color := Color.WHITE

var items := []
var texts := []
var parts := []
var coins := []
var showcase := {}
var banner := {}


func _process(delta: float) -> void:
	shake = maxf(shake - delta * 2.5, 0.0)
	flash = maxf(flash - delta * 2.0, 0.0)

	for it in items:
		it.age += delta
		it.vel.y += GRAVITY * delta
		it.pos += it.vel * delta
		it.rot += it.spin * delta
		if it.pos.y > it.floor_y and it.vel.y > 0.0:
			it.pos.y = it.floor_y
			it.vel.y *= -0.35
			it.vel.x *= 0.6
			it.spin *= 0.5
	_drop_old(items)

	for tx in texts:
		tx.age += delta
		tx.pos += tx.vel * delta
		tx.vel *= 1.0 - delta * 3.0
	_drop_old(texts)

	for p in parts:
		p.age += delta
		p.vel.y += p.grav * delta
		p.vel *= 1.0 - p.drag * delta
		p.pos += p.vel * delta
	_drop_old(parts)

	var arrived := 0
	for i in range(coins.size() - 1, -1, -1):
		coins[i].age += delta
		if coins[i].age >= coins[i].dur:
			arrived += 1
			coins.remove_at(i)
	if arrived > 0:
		coin_arrived.emit()

	if not showcase.is_empty():
		showcase.age += delta
		if showcase.age > showcase.life:
			showcase = {}
	if not banner.is_empty():
		banner.age += delta
		if banner.age > banner.life:
			banner = {}

	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 14.0
	queue_redraw()


func _drop_old(list: Array) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i].age >= list[i].life:
			list.remove_at(i)


# --- Spawning ------------------------------------------------------------------

func spawn_find(find: Dictionary, from: Vector2, index: int, s: float) -> void:
	var dir := -1.0 if randf() < 0.5 else 1.0
	if index > 0:
		dir = -dir
	var it := {
		"id": find.id, "rarity": find.rarity,
		"pos": from, "vel": Vector2(dir * randf_range(260, 520), -randf_range(620, 780)) * clampf(s, 0.7, 1.2),
		"rot": 0.0, "spin": randf_range(-8, 8), "age": 0.0, "life": 1.1,
		"scale": 0.75 * s, "floor_y": from.y + randf_range(150, 220) * s,
	}
	items.append(it)
	if items.size() > MAX_ITEMS:
		items.pop_front()

	var col: Color = GameData.rarities[find.rarity].color
	var size: int = int(clampf(30 * s, 20, 40)) + find.rarity * 6
	if find.crit:
		size += 10
		col = Color("ff5b3a")
	var label := "+" + Game.fmt(find.value)
	if find.crit:
		label += "!"
	texts.append({"text": label, "pos": from + Vector2(randf_range(-40, 40), -60) * s,
		"vel": Vector2(randf_range(-30, 30), -220), "age": 0.0, "life": 0.9, "col": col, "size": size})
	while texts.size() > MAX_TEXTS:
		texts.pop_front()
	if find.crit:
		texts.append({"text": "x10", "pos": from + Vector2(0, -130) * s, "vel": Vector2(0, -120),
			"age": 0.0, "life": 0.8, "col": Color("ffd84a"), "size": size + 8})

	if find.rarity >= 1:
		burst(from + Vector2(0, -40) * s, col, 10 + find.rarity * 8, s)
	if find.rarity >= 2:
		showcase = {"id": find.id, "rarity": find.rarity, "age": 0.0, "life": 1.5 if find.rarity == 3 else 1.1, "new": find.new}
	if find.rarity == 3:
		flash = 0.7
		flash_color = Color(1, 0.9, 0.5)
		shake = maxf(shake, 0.8)


func burst(at: Vector2, col: Color, count: int, s: float) -> void:
	for i in count:
		var a := randf() * TAU
		_part(at, Vector2(cos(a), sin(a)) * randf_range(200, 520) * s, randf_range(0.5, 0.9),
			col, randf_range(5, 10) * s, 1, 400.0, 2.5)


func confetti(rect: Rect2, count := 60) -> void:
	var colors := [Art.RED, Art.YELLOW, Art.BLUE, Art.GREEN, Art.PINK, Art.PURPLE]
	for i in count:
		_part(Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y - 20),
			Vector2(randf_range(-80, 80), randf_range(100, 400)), randf_range(1.5, 2.5),
			colors[i % colors.size()], randf_range(6, 10), 3, 300.0, 1.0)


func flame(at: Vector2, s: float) -> void:
	var col := Color("ff5b3a").lerp(Color("ffd84a"), randf())
	_part(at, Vector2(randf_range(-40, 40), -randf_range(150, 300)) * s, randf_range(0.4, 0.7), col,
		randf_range(8, 14) * s, 0, -100.0, 1.5)


func mini_coin(at: Vector2, s: float) -> void:
	_part(at, Vector2(randf_range(-30, 30), -160) * s, 0.7, Art.GOLD, 0.22 * s, 2, 300.0, 1.0)


func fly_coin(from: Vector2, count := 1) -> void:
	for i in count:
		var ctrl := from.lerp(coin_target, 0.5) + Vector2(randf_range(-160, 160), randf_range(-200, -60))
		coins.append({"from": from + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "ctrl": ctrl,
			"age": -i * 0.05, "dur": randf_range(0.5, 0.7)})
	while coins.size() > 40:
		coins.pop_front()


func float_text(text: String, at: Vector2, col: Color, size: int, life := 1.2) -> void:
	texts.append({"text": text, "pos": at, "vel": Vector2(0, -90), "age": 0.0, "life": life, "col": col, "size": size})


func show_banner(text: String, col: Color, icon := "", life := 1.8, sub := "") -> void:
	banner = {"text": text, "col": col, "icon": icon, "age": 0.0, "life": life, "sub": sub}


func _part(pos: Vector2, vel: Vector2, life: float, col: Color, r: float, kind: int, grav: float, drag: float) -> void:
	parts.append({"pos": pos, "vel": vel, "age": 0.0, "life": life, "col": col, "r": r, "kind": kind,
		"grav": grav, "drag": drag, "rot": randf() * TAU})
	if parts.size() > MAX_PARTS:
		parts.pop_front()


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	for p in parts:
		var k: float = 1.0 - p.age / p.life
		var col: Color = p.col
		match p.kind:
			0:
				Art.dot(self, p.pos, p.r * (0.5 + k * 0.5), Color(col, col.a * k))
			1:
				Art.sparkle(self, p.pos, p.r * (0.4 + k), Color(col.lightened(0.3), k))
			2:
				Art.icon(self, "coin", p.pos, p.r, 0.0, minf(k * 2.0, 1.0))
			3:
				var rot: float = p.rot + p.age * 6.0
				var d: Vector2 = Vector2(cos(rot), sin(rot)) * p.r
				draw_colored_polygon(Art.V([p.pos - d, p.pos + d.orthogonal() * 0.5, p.pos + d, p.pos - d.orthogonal() * 0.5]), Color(col, minf(k * 3.0, 1.0)))

	for it in items:
		var k: float = it.age / it.life
		var a := clampf((1.0 - k) * 4.0, 0.0, 1.0)
		var sc: float = it.scale * (0.6 + minf(it.age * 6.0, 0.4))
		if it.rarity >= 1:
			Art.glow(self, it.pos, 26 * sc, Color(GameData.rarities[it.rarity].color, 0.35 * a))
		Art.item(self, it.id, it.pos, sc, it.rot, Color(0, 0, 0, 0), a)

	for c in coins:
		if c.age < 0.0:
			continue
		var k: float = c.age / c.dur
		var e := k * k
		var p: Vector2 = c.from.lerp(c.ctrl, e).lerp(c.ctrl.lerp(coin_target, e), e)
		Art.icon(self, "coin", p, 0.42 - k * 0.12)

	for tx in texts:
		var k: float = tx.age / tx.life
		var pop := 1.0 + maxf(0.0, 0.3 - tx.age) * 1.5
		var a := clampf((1.0 - k) * 3.0, 0.0, 1.0)
		Art.text(self, tx.text, tx.pos, int(tx.size * pop), Color(tx.col, a))

	_draw_showcase()
	_draw_banner()

	if flash > 0.0:
		draw_rect(area.grow(40), Color(flash_color, flash * 0.5))


func _draw_showcase() -> void:
	if showcase.is_empty():
		return
	var s := clampf(minf(area.size.x, area.size.y) / 600.0, 0.6, 1.3)
	var age: float = showcase.age
	var life: float = showcase.life
	var grow := minf(age * 7.0, 1.0)
	var bounce := 1.0 + sin(minf(age * 7.0, PI)) * 0.25
	var fade := clampf((life - age) * 4.0, 0.0, 1.0)
	var center := Vector2(area.get_center().x, area.position.y + area.size.y * 0.42)
	var col: Color = GameData.rarities[showcase.rarity].color
	Art.rays(self, center, 170 * s * grow, 14, age * 1.5, Color(col, 0.35 * fade))
	Art.glow(self, center, 60 * s * grow, Color(col, 0.35 * fade))
	Art.item(self, showcase.id, center, 1.7 * s * grow * bounce, sin(age * 4.0) * 0.12, Color(0, 0, 0, 0), fade)
	Art.text(self, GameData.rarities[showcase.rarity].name, center + Vector2(0, 95) * s, int(44 * s * bounce), Color(col, fade))
	if showcase.new:
		var tag := center + Vector2(70, -70) * s
		Art.text(self, "NEW!", tag, int(32 * s), Color(Art.YELLOW, fade))


func _draw_banner() -> void:
	if banner.is_empty():
		return
	var s := clampf(minf(area.size.x, area.size.y) / 600.0, 0.6, 1.3)
	var age: float = banner.age
	var life: float = banner.life
	var slide := 1.0 - pow(1.0 - minf(age * 5.0, 1.0), 3.0)
	var fade := clampf((life - age) * 3.0, 0.0, 1.0)
	var center := Vector2(area.get_center().x, area.position.y + area.size.y * 0.38)
	var size := int(58 * s * (0.6 + 0.4 * slide))
	var w := Art.text_width(banner.text, size) + (90 * s if banner.icon != "" else 40 * s)
	var r := Rect2(center - Vector2(w * 0.5, 44 * s), Vector2(w, 88 * s))
	r.position.x += (1.0 - slide) * -area.size.x * 0.6
	var panel_col := Color(Art.OL, 0.75 * fade)
	draw_colored_polygon(Art.rrect(r, 30 * s), panel_col)
	var text_x := r.get_center().x
	if banner.icon != "":
		Art.icon(self, banner.icon, Vector2(r.position.x + 48 * s, r.get_center().y), 0.75 * s, 0.0, fade)
		text_x += 30 * s
	Art.text(self, banner.text, Vector2(text_x, r.get_center().y), size, Color(banner.col, fade))
	if banner.sub != "":
		Art.text(self, banner.sub, Vector2(r.get_center().x, r.end.y + 26 * s), int(28 * s), Color(Art.WHITE, fade))
