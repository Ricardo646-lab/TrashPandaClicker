extends Control

# A small card under the SHOP button. It shows the best thing you can buy
# right now (the most extra income per coin). Tapping it opens the shop at
# that item; buying is always done in the shop. It only shows up when you
# can afford something. Until the very first purchase, a paw says "BUY!".

signal opened(kind: String, index: int)

# How many taps per second we expect from a player, to compare tap
# upgrades with helpers.
const TAPS_PER_SEC := 2.5

var _target := {}
var _show := 0.0
var _down := false
var _bump := 0.0
var _t := 0.0
var _last_state := []
var _check_timer := 0.0
var _has_target := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


# The affordable helper or upgrade with the most extra income per coin:
# {"kind", "index", "cost"}. Empty if nothing is affordable.
func _best() -> Dictionary:
	var best := {}
	var best_value := -1.0
	for i in GameData.helpers.size():
		var cost := Game.helper_cost(i, 1)
		if not Game.helper_unlocked(i) or Game.coins < cost:
			continue
		var value := Game.helper_each(i) * Game.global_mult() / cost
		if value > best_value:
			best_value = value
			best = {"kind": "helper", "index": i, "cost": cost}
	for i in GameData.upgrades.size():
		var cost := Game.upgrade_cost(i)
		if not Game.upgrade_unlocked(i) or Game.upgrade_maxed(i) or Game.coins < cost:
			continue
		var value := _tap_gain(GameData.upgrades[i].id) * TAPS_PER_SEC / cost
		if value > best_value:
			best_value = value
			best = {"kind": "upgrade", "index": i, "cost": cost}
	return best


# Extra coins per tap from one more level of a tap upgrade.
func _tap_gain(id: String) -> float:
	if id == "rage":
		# Rage is active about a third of the time when you tap a lot.
		return Game.expected_tap() * 0.3 * 0.25
	var before := Game.expected_tap()
	Game.upgrades[id] += 1
	var after := Game.expected_tap()
	Game.upgrades[id] -= 1
	return after - before


func _process(delta: float) -> void:
	_t += delta
	_bump = maxf(_bump - delta * 5.0, 0.0)
	# Checking every option takes a little time, so 4 times a second is
	# enough (and right away when the shown item can't be paid any more).
	_check_timer -= delta
	if _check_timer <= 0.0 or (_has_target and Game.coins < _target.cost):
		_check_timer = 0.25
		var target := _best()
		_has_target = not target.is_empty()
		if _has_target:
			_target = target
	var want := 1.0 if _has_target else 0.0
	_show = move_toward(_show, want, delta * 6.0)
	# Clicks only count while the card is (mostly) on screen.
	mouse_filter = Control.MOUSE_FILTER_STOP if _show > 0.5 else Control.MOUSE_FILTER_IGNORE
	var state := [_target, _down, size]
	var moving := (_show > 0.0 and _show < 1.0) or _bump > 0.0 or (_show > 0.0 and Game.never_bought())
	if moving or state != _last_state or fmod(_t, 0.5) < delta:
		_last_state = state
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position) and _has_target:
				_bump = 1.0
				Sfx.play("tab", -4.0)
				opened.emit(_target.kind, _target.index)
		accept_event()


func _draw() -> void:
	if _show <= 0.0 or _target.is_empty():
		return
	var slide := (1.0 - pow(1.0 - _show, 3.0))
	var r := Rect2(Vector2((1.0 - slide) * (size.x + 30.0), 0), size - Vector2(0, 6))
	r = r.grow(sin(_bump * PI) * 4.0)
	if _down:
		r.position.y += 3
	Art.panel(self, r, Color("fff4dc"), 20, 0.0 if _down else 5.0, 4)

	var helper: bool = _target.kind == "helper"
	var i: int = _target.index
	var icon_c := Vector2(r.position.x + r.size.y * 0.5, r.get_center().y)
	var wiggle := sin(_t * 7.0) * 0.1
	if helper:
		Creatures.helper(self, GameData.helpers[i].id, icon_c, r.size.y / 115.0, wiggle)
	else:
		Art.icon(self, GameData.upgrades[i].id, icon_c, r.size.y / 115.0, wiggle)

	# Effect on top, green price button below.
	var tx := r.position.x + r.size.y
	var effect := "+%s/s" % Game.fmt(Game.helper_each(i) * Game.global_mult()) if helper else Game.upgrade_effect(i)
	var effect_size := 17 if Art.text_width(effect, 17) < r.end.x - tx - 10 else 14
	Art.text(self, effect, Vector2(tx, r.position.y + r.size.y * 0.27), effect_size, Color("7b4fe0"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	var br := Rect2(tx, r.position.y + r.size.y * 0.47, r.end.x - tx - 10, r.size.y * 0.42)
	Art.panel(self, br, Color("5ccf4a"), 12, 3, 3)
	Art.icon(self, "coin", Vector2(br.position.x + 15, br.get_center().y), 0.26)
	Art.text(self, Game.fmt(_target.cost), Vector2(br.position.x + 28, br.get_center().y), 18, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)

	# First time: a paw points at the card.
	if Game.never_bought():
		var bounce := absf(sin(_t * 6.0)) * 16.0
		var paw := Vector2(r.position.x - 58 - bounce, r.get_center().y)
		Art.icon(self, "claws", paw, 0.8, PI * 0.5)
		Art.text(self, "BUY!", paw + Vector2(-6, -58), 36, Art.YELLOW)
