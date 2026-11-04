extends Control

# Active boosts (rage, golden frenzy, tap storm) with the time left,
# stacked from the top right of this control.

const BOX := Vector2(150, 58)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var _had_boosts := false


func _process(_delta: float) -> void:
	var has := Game.rage_time > 0.0 or Game.frenzy_time > 0.0 or Game.tapstorm_time > 0.0
	if has or _had_boosts:
		queue_redraw()
	_had_boosts = has


func _draw() -> void:
	var boosts := []
	if Game.rage_time > 0.0:
		boosts.append(["rage", "x" + Game.fmt_small(Game.rage_mult()), Game.rage_time, Color("ff5b3a")])
	if Game.frenzy_time > 0.0:
		boosts.append(["golden", "x" + Game.fmt_small(Game.frenzy_mult), Game.frenzy_time, Art.GOLD_DARK])
	if Game.tapstorm_time > 0.0:
		boosts.append(["claws", "x10", Game.tapstorm_time, Color("4fa8ff")])
	var y := 0.0
	for b in boosts:
		var r := Rect2(Vector2(size.x - BOX.x, y), BOX)
		Art.panel(self, r, b[3], 22, 4, 4)
		Art.icon(self, b[0], Vector2(r.position.x + 30, r.get_center().y), 0.42)
		Art.text(self, b[1], Vector2(r.position.x + 58, r.position.y + 20), 22, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		Art.text(self, _time(b[2]), Vector2(r.position.x + 58, r.position.y + 42), 18, Art.YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
		y += BOX.y + 10


func _time(sec: float) -> String:
	var s := int(ceil(sec))
	if s >= 60:
		return "%d:%02d" % [floori(s / 60.0), s % 60]
	return "%ds" % s
