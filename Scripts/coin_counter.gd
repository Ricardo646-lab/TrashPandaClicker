extends Control

# The coin counter at the top of the screen: coins (rolling up) and
# coins per second. Its size and place are set in hud.tscn.

var shown_coins := 0.0
var _bump := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown_coins = Game.coins


# A coin from the play area arrived: make the counter bounce.
func bump() -> void:
	_bump = 1.0


# Where flying coins should go (canvas coordinates).
func coin_global_pos() -> Vector2:
	return global_position + Vector2(size.y * 0.5, size.y * 0.5)


func _process(delta: float) -> void:
	_t += delta
	_bump = maxf(_bump - delta * 5.0, 0.0)
	# The counter rolls towards the real amount.
	if Game.coins < shown_coins:
		shown_coins = Game.coins
	else:
		shown_coins = lerpf(shown_coins, Game.coins, minf(delta * 10.0, 1.0))
		if Game.coins - shown_coins < 1.0:
			shown_coins = Game.coins
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := size.y / 92.0
	Art.panel(self, r, Color(0.17, 0.12, 0.21, 0.82), 30 * k, 0, 4)
	var pop := 1.0 + sin(_bump * PI) * 0.25
	Art.icon(self, "coin", Vector2(size.y * 0.5, size.y * 0.5), 0.82 * k * pop, sin(_t * 2.0) * 0.08)
	var big := int(48 * k * (1.0 + sin(_bump * PI) * 0.06))
	var tx := 92 * k
	Art.text(self, Game.fmt(shown_coins), Vector2(tx, 36 * k), big, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "%s /s" % Game.fmt(Game.cps()), Vector2(tx, 72 * k), int(24 * k), Color("ffd84a"), HORIZONTAL_ALIGNMENT_LEFT)
