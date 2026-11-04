extends Control

# Progress towards the next world. When you can pay for it, it turns
# green and bounces: tap it to travel.

signal travel_pressed

var _t := 0.0
var _down := false
var _redraw_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	# Every frame while it bounces (ready to travel), otherwise 15 times a second.
	_redraw_timer -= delta
	if _down or ready_to_go() or _redraw_timer <= 0.0:
		_redraw_timer = 1.0 / 15.0
		queue_redraw()


func ready_to_go() -> bool:
	return Game.coins >= Game.next_world_cost()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				if ready_to_go():
					travel_pressed.emit()
				else:
					Sfx.play("deny", -8.0)
		accept_event()


func _draw() -> void:
	if not Game.has_next_world():
		return
	var go := ready_to_go()
	var grow := (sin(_t * 7.0) * 3.0) if go else 0.0
	var r := Rect2(Vector2.ZERO, size - Vector2(0, 6)).grow(grow)
	if _down:
		r.position.y += 3
	Art.panel(self, r, Color("5ccf4a") if go else Color(0.17, 0.12, 0.21, 0.82), r.size.y * 0.5, 5.0 if go else 0.0, 4)

	var next: WorldData = GameData.worlds[Game.world + 1]
	# Little round "window" showing the next world's legendary item.
	var c := Vector2(r.position.x + r.size.y * 0.5, r.get_center().y)
	var rad := r.size.y * 0.5 - 4
	draw_circle(c, rad + 3, Art.OL, true, -1.0, true)
	draw_circle(c, rad, Color("ffe9b0") if go else Color("4b3d63"), true, -1.0, true)
	Art.item(self, _best_item(next), c, rad / 42.0, sin(_t * 2.0) * 0.1, Color(0, 0, 0, 0) if go else Color("2b1f35"))
	if not go:
		Art.text(self, "?", c, int(rad * 1.1), Art.WHITE)

	var text_x := c.x + rad + 12
	var bar := Rect2(text_x, r.get_center().y + 2, r.end.x - text_x - 16, r.size.y * 0.26)
	if go:
		Art.text(self, "GO TO " + next.name.to_upper() + "!", Vector2((text_x + r.end.x - 10) * 0.5, r.get_center().y), int(r.size.y * 0.36))
		return
	Art.text(self, next.name, Vector2(text_x, r.position.y + r.size.y * 0.3), int(r.size.y * 0.3), Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var k := clampf(Game.coins / Game.next_world_cost(), 0.0, 1.0)
	draw_colored_polygon(Art.rrect(bar.grow(3), bar.size.y * 0.5 + 3), Art.OL)
	draw_colored_polygon(Art.rrect(bar, bar.size.y * 0.5), Color("3b3550"))
	if k > 0.02:
		draw_colored_polygon(Art.rrect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), bar.size.y * 0.5), Art.GOLD)
	Art.icon(self, "coin", Vector2(r.end.x - 70, r.position.y + r.size.y * 0.3), r.size.y / 210.0)
	Art.text(self, Game.fmt(Game.next_world_cost()), Vector2(r.end.x - 16, r.position.y + r.size.y * 0.3), int(r.size.y * 0.28), Art.YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)


# The rarest item of a world, shown as a preview.
func _best_item(world: WorldData) -> String:
	var best: ItemData = world.items[0]
	for it in world.items:
		if it.rarity > best.rarity:
			best = it
	return best.id
