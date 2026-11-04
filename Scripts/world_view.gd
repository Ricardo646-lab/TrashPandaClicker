extends Node2D

# The play area: the trash can with the raccoon, the rage meter and the
# golden trash event. Tapping anywhere in the area digs. The background and
# the helpers are drawn by backdrop.gd (a layer that is rarely redrawn).

signal tapped(result: Dictionary, from: Vector2)
signal golden_collected(kind: String, pos: Vector2)

const POP_TIME := 0.22
const GOLDEN_FIRST := 25.0
const GOLDEN_MIN := 50.0
const GOLDEN_MAX := 110.0
const GOLDEN_LIFE := 10.0

# Where the helpers stand: x as a fraction of the area width, y from the
# ground line (0) to the bottom edge (1).
const SLOTS := [
	Vector2(0.22, 0.0), Vector2(0.78, 0.0), Vector2(0.08, 0.05), Vector2(0.92, 0.05),
	Vector2(0.3, 1.0), Vector2(0.7, 1.0), Vector2(0.13, 0.95), Vector2(0.87, 0.95), Vector2(0.5, 1.0),
]

var rect := Rect2(0, 0, 800, 600)
var fx: Node2D
# False on the start screen and while a menu is open: no tapping and no
# golden trash then.
var active := false

var t := 0.0
var pop := 0.0
var squash := 0.0
var lid_y := 0.0
var lid_vel := 0.0
var lid_spin := 0.0
var blink := 0.0
var blink_timer := 2.0
var happy_time := 0.0
var wow_time := 0.0
var look := Vector2.ZERO

var golden_timer := GOLDEN_FIRST
var golden_active := false
var golden_pos := Vector2.ZERO
var golden_age := 0.0
var golden_seed := 0.0


func scale_factor() -> float:
	return clampf(minf(rect.size.x / 600.0, rect.size.y / 660.0), 0.5, 1.3)


func bin_base() -> Vector2:
	var k := 0.84 if rect.size.x >= rect.size.y else 0.8
	return Vector2(rect.get_center().x, rect.position.y + rect.size.y * k)


func head_pos() -> Vector2:
	var s := scale_factor()
	var lift := sin(clampf(pop, 0.0, 1.0) * PI) * 26.0
	var breathe := sin(t * 2.2) * 3.0
	return bin_base() + Vector2(0, Scenery.RIM_Y - 34 - lift + breathe) * s


# Where found items fly out from.
func mouth_pos() -> Vector2:
	return bin_base() + Vector2(0, Scenery.RIM_Y - 10) * scale_factor()


func _process(delta: float) -> void:
	t += delta
	pop = maxf(pop - delta / POP_TIME, 0.0)
	squash = move_toward(squash, 0.0, delta * 6.0)
	happy_time -= delta
	wow_time -= delta

	# Lid: flies up on a tap, falls back onto the raccoon's head.
	lid_vel += 3200.0 * delta
	lid_y += lid_vel * delta
	if lid_y > 0.0:
		lid_y = 0.0
		lid_vel = -absf(lid_vel) * 0.25 if absf(lid_vel) > 200.0 else 0.0
	lid_spin = move_toward(lid_spin, 0.0, delta * 3.0)

	blink_timer -= delta
	if blink_timer <= 0.0:
		blink = 1.0
		blink_timer = randf_range(1.8, 4.5)
	blink = maxf(blink - delta * 7.0, 0.0)

	var mouse := get_global_mouse_position()
	var target := ((mouse - head_pos()) / 250.0).limit_length(1.0)
	look = look.lerp(target, minf(delta * 8.0, 1.0))

	_update_golden(delta)
	if Game.rage_time > 0.0 and fx and randf() < 0.3:
		fx.flame(mouth_pos() + Vector2(randf_range(-80, 80), 0) * scale_factor(), scale_factor())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
	if not press and not key:
		return
	var pos := mouth_pos()
	if press:
		pos = make_input_local(event).position
		if not rect.has_point(pos):
			return
		if golden_active and pos.distance_to(golden_pos) < 70.0 * scale_factor():
			_collect_golden()
			get_viewport().set_input_as_handled()
			return
	tap(pos)
	get_viewport().set_input_as_handled()


func tap(_at: Vector2) -> void:
	var result := Game.dig()
	pop = 1.0
	squash = 1.0
	lid_vel = -randf_range(700.0, 950.0)
	lid_spin = randf_range(-1.0, 1.0)
	happy_time = 0.3
	var best := 0
	for find in result.finds:
		best = maxi(best, find.rarity)
	if best >= 2:
		wow_time = 0.8
	if not Game.tutorial_done and Game.taps >= 5:
		Game.tutorial_done = true
	tapped.emit(result, mouth_pos())



# --- Golden trash ---------------------------------------------------------------

func _update_golden(delta: float) -> void:
	if golden_active:
		if active:
			golden_age += delta
		var s := scale_factor()
		var drift := Vector2(sin(golden_age * 0.9 + golden_seed) * 60.0, cos(golden_age * 1.3 + golden_seed) * 30.0) * s
		golden_pos = _golden_home + drift
		if golden_age > GOLDEN_LIFE:
			golden_active = false
		return
	if not active:
		return
	golden_timer -= delta
	if golden_timer <= 0.0:
		golden_timer = randf_range(GOLDEN_MIN, GOLDEN_MAX)
		golden_active = true
		golden_age = 0.0
		golden_seed = randf() * TAU
		var side := -1.0 if randf() < 0.5 else 1.0
		_golden_home = Vector2(rect.get_center().x + side * rect.size.x * randf_range(0.22, 0.32),
			rect.position.y + rect.size.y * randf_range(0.35, 0.55))
		golden_pos = _golden_home
		Sfx.play("golden_appear", -4.0)


var _golden_home := Vector2.ZERO


func _collect_golden() -> void:
	golden_active = false
	var roll := randf()
	var kind := "lucky"
	if roll < 0.42:
		kind = "frenzy"
	elif roll < 0.68:
		kind = "storm"
	golden_collected.emit(kind, golden_pos)


func helper_pos(index: int) -> Vector2:
	var slot: Vector2 = SLOTS[index]
	var s := scale_factor()
	var top := Scenery.ground_y(rect) + 34.0 * s
	var bottom := rect.end.y - 62.0 * s
	return Vector2(rect.position.x + rect.size.x * slot.x, lerpf(top, maxf(bottom, top), slot.y))


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	var s := scale_factor()
	_draw_bin(s)

	_draw_rage_meter(s)
	if golden_active:
		_draw_golden(s)
	if active and not Game.tutorial_done and Game.taps < 5:
		_draw_hint(s)


func _draw_bin(s: float) -> void:
	var base := bin_base()
	var sq := sin(squash * PI) * squash
	var scale_v := Vector2(s * (1.0 + 0.08 * sq), s * (1.0 - 0.1 * sq))

	# Shadow.
	Art.shadow(self, base + Vector2(0, 4 * s), 125 * s, 18 * s, Color(0, 0, 0, 0.22))

	# Rage glow.
	if Game.rage_time > 0.0:
		var pulse := 0.6 + 0.4 * sin(t * 14.0)
		if not Bake.draw(self, "fx_glow", base + Vector2(0, -150 * s), Vector2.ONE * (270 * s / Bake.FX_RADIUS), 0.0, Color(1, 0.35, 0.1, 0.55 * pulse)):
			for k in 3:
				draw_circle(base + Vector2(0, -150 * s), (190 + k * 40) * s, Color(1, 0.3, 0.1, 0.09 * pulse), true, -1.0, true)

	# Tail sticks out of the right side and swishes.
	var swish := sin(t * 2.6) * 0.6 + (0.6 if happy_time > 0.0 else 0.0)
	var tail_pos := base + Vector2(62, -70) * scale_v
	if not Bake.draw(self, "tail", tail_pos, Vector2(s, s), 0.55 + swish * 0.12):
		Art.draw_groups(self, Creatures.tail(swish), tail_pos, s, 0.55)

	if not Bake.draw(self, "bin_back", base, scale_v):
		draw_set_transform(base, 0.0, scale_v)
		Art.render(self, Scenery.bin_back())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var mood := Creatures.Mood.IDLE
	if Game.rage_time > 0.0:
		mood = Creatures.Mood.RAGE
	elif wow_time > 0.0:
		mood = Creatures.Mood.WOW
	elif happy_time > 0.0:
		mood = Creatures.Mood.HAPPY
	var ear := sin(t * 9.0) * 0.12 if fmod(t, 3.7) < 0.35 else 0.0
	var head := head_pos()
	head.y = base.y + (head.y - base.y) * (scale_v.y / s)
	# The head is baked; only the eyes are drawn live (they follow the mouse).
	var hs := Vector2(s, s) * 1.1
	if Bake.draw(self, "head_%d" % mood, head, hs):
		Art.draw_groups(self, Creatures.raccoon_head(look, blink, mood, 0.0, Creatures.FUR, Creatures.Part.EYES), head, hs.x)
	else:
		Art.draw_groups(self, Creatures.raccoon_head(look, blink, mood, ear), head, hs.x)

	if not Bake.draw(self, "bin_front", base, scale_v):
		draw_set_transform(base, 0.0, scale_v)
		Art.render(self, Scenery.bin_front())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Paws hold the rim.
	var paw_lift := sin(clampf(pop, 0.0, 1.0) * PI) * 14.0
	var paw := Art.cached("paw", func() -> Array: return Creatures.raccoon_paw())
	for side in [-1.0, 1.0]:
		var paw_pos := base + Vector2(58 * side, Scenery.RIM_Y + 6 - paw_lift) * scale_v
		if not Bake.draw(self, "paw", paw_pos, Vector2(s, s), 0.15 * side):
			Art.draw_groups(self, paw, paw_pos, s, 0.15 * side)

	# The lid sits on the raccoon's head like a hat.
	var lid_pos := head + Vector2(14, -52 * 1.1 + lid_y * 0.12) * s
	var lid_rot := -0.2 + lid_spin * 0.4 + sin(t * 2.2) * 0.03
	if not Bake.draw(self, "lid", lid_pos, Vector2(s, s) * 0.82, lid_rot):
		Art.draw_groups(self, Scenery.lid(), lid_pos, s * 0.82, lid_rot)


func _draw_rage_meter(s: float) -> void:
	var base := bin_base()
	var h := 150.0 * s
	var w := 22.0 * s
	var r := Rect2(base + Vector2(-150 * s - w, -h - 40 * s), Vector2(w, h))
	var fill := Game.rage
	var raging := Game.rage_time > 0.0
	draw_colored_polygon(Art.rrect(r.grow(4), w * 0.5 + 4), Art.OL)
	draw_colored_polygon(Art.rrect(r, w * 0.5), Color("3b3550"))
	if fill > 0.02:
		var fr := Rect2(r.position + Vector2(0, h * (1.0 - fill)), Vector2(w, h * fill))
		var col := Color("ff5b3a").lerp(Color("ffd84a"), 0.5 + 0.5 * sin(t * 20.0)) if raging else Color("ff9a3c").lerp(Color("ff3b3b"), fill)
		draw_colored_polygon(Art.rrect(fr, w * 0.5), col)
	var icon_scale := s * (0.42 + (0.08 * sin(t * 16.0) if raging else 0.0))
	Art.icon(self, "rage", Vector2(r.get_center().x, r.position.y - 18 * s), icon_scale)


func _draw_golden(s: float) -> void:
	var p := golden_pos
	var fade := clampf(golden_age * 3.0, 0.0, 1.0) * clampf((GOLDEN_LIFE - golden_age) * 2.0, 0.0, 1.0)
	var blink_out := 1.0
	if GOLDEN_LIFE - golden_age < 2.5:
		blink_out = 0.5 + 0.5 * signf(sin(golden_age * 20.0))
	Art.rays(self, p, 95 * s, 12, t * 0.8, Color(1, 0.9, 0.3, 0.3 * fade * blink_out))
	Art.glow(self, p, 30 * s, Color(1, 0.9, 0.4, 0.25 * fade))
	Art.icon(self, "golden", p, s * (1.05 + 0.08 * sin(t * 6.0)), sin(t * 3.0) * 0.15, fade * blink_out)
	for k in 3:
		var a := t * 2.0 + k * TAU / 3.0
		Art.sparkle(self, p + Vector2(cos(a), sin(a)) * 60 * s, (6 + 3 * sin(t * 8.0 + k)) * s, Color(1, 1, 1, fade))


func _draw_hint(s: float) -> void:
	var p := bin_base() + Vector2(0, -120) * s
	var bounce := absf(sin(t * 5.0)) * 18.0 * s
	var pulse := 1.0 + 0.06 * sin(t * 10.0)
	Art.text(self, "TAP!", p + Vector2(0, -bounce), int(46 * s * pulse), Art.YELLOW)
	Art.icon(self, "claws", p + Vector2(110, 40 - bounce) * s, 0.8 * s, -0.5)
