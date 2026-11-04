extends Node2D

# The background and the helper crew. They hardly ever change, so this
# layer is only redrawn when something changes (a helper bought, another
# world, another screen size), not 60 times a second.

@export var world: Node2D

var _state := []
var _bounce: Array[float] = []


func _ready() -> void:
	for i in GameData.helpers.size():
		_bounce.append(0.0)
	Game.purchased.connect(func(kind: String, index: int) -> void:
		if kind == "helper":
			_bounce[index] = 1.0)


func _process(delta: float) -> void:
	var animating := false
	for i in _bounce.size():
		if _bounce[i] > 0.0:
			_bounce[i] = maxf(_bounce[i] - delta * 3.0, 0.0)
			animating = true
	var bg := Bake.background(Game.world, world.rect.size)
	var state := [Game.world, world.rect, Game.helpers.duplicate(), bg.get_instance_id() if bg else 0, Bake.atlas != null]
	if animating or state != _state:
		_state = state
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = world.rect
	var bg := Bake.background(Game.world, rect.size)
	if bg:
		draw_texture_rect(bg, rect, false)
	else:
		Scenery.background(self, Game.world, rect, 0.0)
	var s: float = world.scale_factor()
	for i in Game.helpers.size():
		if Game.helpers[i] > 0:
			_draw_helper(i, s)


func _draw_helper(i: int, s: float) -> void:
	var id: String = GameData.helpers[i].id
	var p: Vector2 = world.helper_pos(i)
	var count := Game.helpers[i]
	var hs := s * 0.85
	# A helper only jumps when you buy one.
	var b := _bounce[i]
	var stretch := 1.0 + sin(b * PI) * 0.25
	Art.shadow(self, p + Vector2(0, 30 * hs), 34 * hs, 8 * hs, Color(0, 0, 0, 0.2))
	# More copies appear when you own more (Egg, Inc. style growth).
	if count >= 50:
		Creatures.helper(self, id, p + Vector2(26, -14) * hs, hs * 0.72)
	if count >= 10:
		Creatures.helper(self, id, p + Vector2(-26, -12) * hs, hs * 0.8)
	Creatures.helper(self, id, p + Vector2(0, -sin(b * PI) * 16.0 * s), hs * stretch)
	Art.text(self, "x%d" % count, p + Vector2(0, 46 * hs), int(clampf(20 * s, 14, 26)), Art.WHITE)
