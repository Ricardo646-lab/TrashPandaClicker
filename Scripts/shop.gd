extends Control

# The shop panel: two tabs (tap upgrades / helpers), a buy-amount toggle
# and a scrolling list. Drawn and scrolled by hand so it behaves the same
# with mouse and touch: drag to scroll, tap to buy, hold to keep buying.

const ROW_H := 100.0
const HEADER_H := 92.0
const PAD := 10.0
const DRAG_START := 12.0
const HOLD_DELAY := 0.4

const BG := Color("6a4a8c")
const ROW := Color("fff4dc")
const ROW_OFF := Color("e6dcef")
const BUY := Color("5ccf4a")
const BUY_OFF := Color("a49cb4")

var tab := 1
var amount_mode := 0
var scroll := 0.0
var scroll_vel := 0.0

var _t := 0.0
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _target := {}
var _hold := 0.0
var _repeat := 0.0
var _repeated := false
var _bumps := {}
# The row the buy card pointed at: it glows for a few seconds.
var _focus_key := ""
var _focus_time := 0.0
var _redraw_timer := 0.0
var _shakes := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func amount() -> int:
	return [1, 10, -1][amount_mode]


func list_rect() -> Rect2:
	return Rect2(PAD, HEADER_H, size.x - PAD * 2.0, size.y - HEADER_H - PAD)


# Rows: {"kind": "upgrade"/"helper", "index": i, "mystery": bool}
func rows() -> Array:
	var out := []
	if tab == 0:
		for i in GameData.upgrades.size():
			var mystery := not Game.upgrade_unlocked(i)
			out.append({"kind": "upgrade", "index": i, "mystery": mystery})
			if mystery:
				break
	else:
		for i in GameData.helpers.size():
			var mystery := not Game.helper_unlocked(i)
			out.append({"kind": "helper", "index": i, "mystery": mystery})
			if mystery:
				break
	return out


# Opens the right tab and scrolls to an item, which then glows.
func focus(kind: String, index: int) -> void:
	tab = 1 if kind == "helper" else 0
	var all := rows()
	for i in all.size():
		if all[i].kind == kind and all[i].index == index:
			var list := list_rect()
			scroll = clampf(i * ROW_H - (list.size.y - ROW_H) * 0.5, 0.0, max_scroll())
			scroll_vel = 0.0
	_focus_key = "%s_%d" % [kind, index]
	_focus_time = 3.0


func max_scroll() -> float:
	return maxf(rows().size() * ROW_H - list_rect().size.y + PAD, 0.0)


func _process(delta: float) -> void:
	_t += delta
	for key in _bumps.keys():
		_bumps[key] = maxf(_bumps[key] - delta * 5.0, 0.0)
	for key in _shakes.keys():
		_shakes[key] = maxf(_shakes[key] - delta * 4.0, 0.0)

	if not _pressing:
		scroll += scroll_vel * delta
		scroll_vel *= pow(0.02, delta)
		if absf(scroll_vel) < 5.0:
			scroll_vel = 0.0
	var top := max_scroll()
	if scroll < 0.0 or scroll > top:
		scroll = lerpf(scroll, clampf(scroll, 0.0, top), minf(delta * 12.0, 1.0))
		if not _pressing:
			scroll_vel = 0.0

	# Hold a buy button to keep buying.
	if _pressing and not _dragging and _target.get("type", "") == "row":
		_hold += delta
		if _hold > HOLD_DELAY:
			_repeat -= delta
			if _repeat <= 0.0:
				_repeat = maxf(0.11 - (_hold - HOLD_DELAY) * 0.03, 0.04)
				_repeated = true
				_activate(_target, true)
	# Redraw every frame while something moves; otherwise 15 times a
	# second is enough for the prices and coins (saves a lot on phones).
	_redraw_timer -= delta
	_focus_time = maxf(_focus_time - delta, 0.0)
	var moving := _pressing or scroll_vel != 0.0 or scroll < 0.0 or scroll > top or _focus_time > 0.0 \
		or (_focus_key != "" and Game.never_bought())
	for v in _bumps.values() + _shakes.values():
		moving = moving or v > 0.0
	if moving or _redraw_timer <= 0.0:
		_redraw_timer = 1.0 / 15.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scroll_vel = 0.0
			scroll = maxf(scroll - 70.0, 0.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scroll_vel = 0.0
			scroll = minf(scroll + 70.0, max_scroll())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragging = false
				_repeated = false
				_press_pos = event.position
				_last_pos = event.position
				_hold = 0.0
				_repeat = 0.0
				scroll_vel = 0.0
				_target = _hit(event.position)
			else:
				if _pressing and not _dragging and not _repeated:
					_activate(_target, false)
				_pressing = false
				_dragging = false
				_target = {}
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_START and list_rect().has_point(_press_pos):
			_dragging = true
		if _dragging:
			var dy: float = event.position.y - _last_pos.y
			var top := max_scroll()
			if scroll < 0.0 or scroll > top:
				dy *= 0.4
			scroll -= dy
			scroll_vel = -event.velocity.y if absf(event.velocity.y) < 4000.0 else 0.0
		_last_pos = event.position
		accept_event()


func _hit(pos: Vector2) -> Dictionary:
	if pos.y < HEADER_H:
		var tabs := _tab_rects()
		for i in tabs.size():
			if tabs[i].has_point(pos):
				return {"type": "tab", "index": i}
		if _amount_rect().has_point(pos):
			return {"type": "amount"}
		return {}
	var list := list_rect()
	if not list.has_point(pos):
		return {}
	var i := int(floor((pos.y - list.position.y + scroll) / ROW_H))
	var all := rows()
	if i >= 0 and i < all.size():
		return {"type": "row", "row": all[i]}
	return {}


func _activate(target: Dictionary, repeating: bool) -> void:
	match target.get("type", ""):
		"tab":
			if tab != target.index:
				tab = target.index
				scroll = 0.0
				Sfx.play("tab")
		"amount":
			amount_mode = (amount_mode + 1) % 3
			Sfx.play("tab")
		"row":
			var row: Dictionary = target.row
			var key := "%s_%d" % [row.kind, row.index]
			var ok := false
			if row.mystery:
				ok = false
			elif row.kind == "helper":
				ok = Game.buy_helper(row.index, amount())
			else:
				ok = Game.buy_upgrade(row.index, amount())
			if ok:
				_bumps[key] = 1.0
				Sfx.play("buy", -2.0, randf_range(0.95, 1.08) + (0.1 if repeating else 0.0))
			elif not repeating:
				_shakes[key] = 1.0
				Sfx.play("deny", -6.0)


func _tab_rects() -> Array:
	var tabs_w := size.x - PAD * 2.0 - 104.0
	var w := (tabs_w - 10.0) * 0.5
	return [Rect2(PAD, 12, w, HEADER_H - 24), Rect2(PAD + w + 10, 12, w, HEADER_H - 24)]


func _amount_rect() -> Rect2:
	return Rect2(size.x - PAD - 96, 14, 96, HEADER_H - 28)


func can_afford_any(which_tab: int) -> bool:
	if which_tab == 0:
		for i in GameData.upgrades.size():
			if Game.upgrade_unlocked(i) and not Game.upgrade_maxed(i) and Game.coins >= Game.upgrade_cost(i):
				return true
		return false
	for i in GameData.helpers.size():
		if Game.helper_unlocked(i) and Game.coins >= Game.helper_unit_cost(i, Game.helpers[i]):
			return true
	return false


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Soft diagonal stripes so the panel isn't flat.
	var x := -size.y
	while x < size.x:
		draw_colored_polygon(Art.V([Vector2(x, size.y), Vector2(x + 40, size.y), Vector2(x + 40 + size.y, 0), Vector2(x + size.y, 0)]), Color(1, 1, 1, 0.03))
		x += 90
	draw_rect(Rect2(0, 0, 5, size.y), Art.OL)
	draw_rect(Rect2(0, 0, size.x, 4), Art.OL)

	var list := list_rect()
	var all := rows()
	for i in all.size():
		var y := list.position.y + i * ROW_H - scroll
		if y > size.y or y + ROW_H < HEADER_H - ROW_H:
			continue
		_draw_row(all[i], Rect2(list.position.x, y + 4, list.size.x, ROW_H - 10))

	# Header on top of the scrolled rows.
	draw_rect(Rect2(0, 0, size.x, HEADER_H), BG.darkened(0.15))
	draw_rect(Rect2(0, HEADER_H - 4, size.x, 4), Art.OL)
	var tabs := _tab_rects()
	var tab_names := ["TAP", "HELPERS"]
	for i in 2:
		var active := tab == i
		var r: Rect2 = tabs[i]
		if not active:
			r.position.y += 4
		Art.panel(self, r, Color("ffb13b") if active else Color("8f74b0"), 18, 0.0 if not active else 5.0, 4)
		var cy := r.get_center().y
		if i == 0:
			Art.icon(self, "claws", Vector2(r.position.x + 34, cy), 0.5)
		else:
			Creatures.helper(self, "kit", Vector2(r.position.x + 34, cy), 0.5)
		Art.text(self, tab_names[i], Vector2(r.position.x + 62, cy), 22, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		if can_afford_any(i):
			var b := Vector2(r.end.x - 8, r.position.y + 8)
			var pulse := 1.0 + 0.15 * sin(_t * 8.0)
			draw_circle(b, 13 * pulse, Art.OL, true, -1.0, true)
			draw_circle(b, 10 * pulse, Art.RED, true, -1.0, true)
			Art.text(self, "!", b, 18, Art.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)
	var ar := _amount_rect()
	Art.panel(self, ar, Color("4fa8ff"), 16, 5, 4)
	Art.text(self, ["x1", "x10", "MAX"][amount_mode], ar.get_center() + Vector2(0, -2), 26)


func _draw_row(row: Dictionary, r: Rect2) -> void:
	var key := "%s_%d" % [row.kind, row.index]
	var bump: float = _bumps.get(key, 0.0)
	var shake: float = _shakes.get(key, 0.0)
	r.position.x += sin(shake * 30.0) * shake * 8.0
	r = r.grow(sin(bump * PI) * 3.0)
	var is_helper: bool = row.kind == "helper"
	var i: int = row.index
	var mystery: bool = row.mystery

	var cost := 0.0
	var maxed := false
	var level := 0
	var title := "???"
	var effect := ""
	var buy_count := 1
	if is_helper:
		buy_count = Game.helper_buy_amount(i, amount())
		cost = Game.helper_cost(i, buy_count)
		level = Game.helpers[i]
		if not mystery:
			title = GameData.helpers[i].name
			effect = "+%s/s" % Game.fmt(Game.helper_each(i) * Game.global_mult() * buy_count)
	else:
		buy_count = Game.upgrade_buy_amount(i, amount())
		cost = Game.upgrade_cost_n(i, buy_count)
		maxed = Game.upgrade_maxed(i)
		level = Game.level(GameData.upgrades[i].id)
		if not mystery:
			title = GameData.upgrades[i].name
			effect = Game.upgrade_effect(i)
	if mystery:
		effect = Game.unlock_hint(row.kind, i)
	var afford := not maxed and not mystery and Game.coins >= cost

	Art.panel(self, r, ROW if afford or maxed else ROW_OFF, 16, 5, 4)

	# Icon.
	var box := Rect2(r.position + Vector2(8, 8), Vector2(r.size.y - 16, r.size.y - 16))
	draw_colored_polygon(Art.rrect(box, 14), Color("ffe1a8") if afford else Color("d4c8e0"))
	var c := box.get_center()
	var wiggle := sin(_t * 7.0) * 0.08 if afford else 0.0
	if mystery:
		if is_helper:
			Creatures.helper_silhouette(self, GameData.helpers[i].id, c, 0.62)
		else:
			Art.icon(self, "lock", c, 0.7)
	elif is_helper:
		Creatures.helper(self, GameData.helpers[i].id, c, 0.62, wiggle)
	else:
		Art.icon(self, GameData.upgrades[i].id, c, 0.68, wiggle)
	if level > 0:
		var lb := box.end - Vector2(6, 8)
		var txt := str(level)
		var w := maxf(Art.text_width(txt, 18) + 14, 28)
		var lr := Rect2(lb - Vector2(w * 0.5, 13), Vector2(w, 26))
		draw_colored_polygon(Art.rrect(lr.grow(3), 15), Art.OL)
		draw_colored_polygon(Art.rrect(lr, 12), Color("7b5cff"))
		Art.text(self, txt, lr.get_center(), 18, Art.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)

	# Price button.
	var bw := clampf(r.size.x * 0.34, 110, 150)
	var br := Rect2(r.end.x - bw - 8, r.position.y + 12, bw, r.size.y - 26)
	if maxed:
		Art.panel(self, br, Art.GOLD, 14, 5, 4)
		Art.text(self, "MAX", br.get_center(), 26)
	elif mystery:
		Art.panel(self, br, BUY_OFF, 14, 5, 4)
		Art.icon(self, "lock", br.get_center() + Vector2(0, -2), 0.6)
	else:
		var pressed: bool = _pressing and not _dragging and _target.get("type", "") == "row" and _target.row.kind == row.kind and _target.row.index == i
		var pr := br
		if pressed:
			pr.position.y += 3
		Art.panel(self, pr, BUY if afford else BUY_OFF, 14, 0.0 if pressed else 5.0, 4)
		Art.icon(self, "coin", Vector2(pr.position.x + 22, pr.get_center().y), 0.36)
		var price := Game.fmt(cost)
		var size_px := 24 if price.length() <= 6 else 20
		Art.text(self, price, Vector2(pr.position.x + 40, pr.get_center().y), size_px, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		if amount() != 1:
			Art.text(self, "x%d" % buy_count, Vector2(pr.end.x - 4, pr.position.y - 2), 16, Art.YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
		# The item the buy card pointed at glows; before the first buy a paw
		# points at its price button.
		if key == _focus_key:
			if _focus_time > 0.0:
				var glow := 0.5 + 0.5 * sin(_t * 10.0)
				draw_polyline(Art.closed(Art.rrect(r.grow(6), 22)), Color(Art.YELLOW, 0.5 + 0.5 * glow), 6.0, true)
			if Game.never_bought():
				var bounce := absf(sin(_t * 6.0)) * 12.0
				var paw := Vector2(pr.position.x - 34 - bounce, pr.get_center().y)
				Art.icon(self, "claws", paw, 0.55, PI * 0.5)
				Art.text(self, "BUY!", paw + Vector2(-2, -38), 24, Art.YELLOW)

	# Name, effect and the next x2 milestone for helpers.
	var tx := box.end.x + 12
	var name_size := 22 if title.length() <= 11 else 19
	Art.text(self, title, Vector2(tx, r.position.y + 26), name_size, Art.OL, HORIZONTAL_ALIGNMENT_LEFT, 0)
	if effect != "":
		var effect_col := Color("8a7aa3") if mystery else Color("7b4fe0")
		var effect_size := 19 if Art.text_width(effect, 19) < br.position.x - tx - 8 else 16
		Art.text(self, effect, Vector2(tx, r.position.y + 52), effect_size, effect_col, HORIZONTAL_ALIGNMENT_LEFT, 0)
	if is_helper and not mystery:
		var m := Game.milestone_range(level)
		var bar := Rect2(tx, r.position.y + 68, br.position.x - tx - 34, 10)
		if bar.size.x > 20:
			var k := clampf(float(level - m.x) / float(m.y - m.x), 0.0, 1.0)
			draw_colored_polygon(Art.rrect(bar.grow(2), 7), Art.OL)
			draw_colored_polygon(Art.rrect(bar, 5), Color("d4c8e0"))
			if k > 0.01:
				draw_colored_polygon(Art.rrect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), 5), Art.ORANGE)
			Art.text(self, "x2", Vector2(bar.end.x + 16, bar.get_center().y), 15, Art.ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 3)
