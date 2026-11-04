extends Control

# Full-screen popups: the item album, offline earnings and prestige.
# Buttons are drawn by hand; their rects are stored while drawing and
# checked on release.

signal action(id: String)

var mode := ""
var _anim := 0.0
var _t := 0.0
var _buttons := []
var _down_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(new_mode: String) -> void:
	mode = new_mode
	_anim = 0.0
	visible = true
	Sfx.play("whoosh", -6.0)


func close() -> void:
	mode = ""
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_anim = minf(_anim + delta * 5.0, 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down_id = _button_at(event.position)
		else:
			var id := _button_at(event.position)
			if id != "" and id == _down_id:
				Sfx.play("tab")
				action.emit(id)
			elif id == "" and _down_id == "" and not _panel_rect().has_point(event.position) and mode == "album":
				close()
			_down_id = ""
	accept_event()


func _button_at(pos: Vector2) -> String:
	for b in _buttons:
		if b.rect.has_point(pos) and b.enabled:
			return b.id
	return ""


func _panel_rect() -> Rect2:
	var w := minf(size.x - 30, 560)
	var h := 0.0
	match mode:
		"album":
			h = minf(size.y - 30, 650)
		"offline":
			h = 400
		"prestige":
			h = 470
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


func _button(rect: Rect2, id: String, col: Color, label: String, icon := "", enabled := true) -> void:
	var pressed := _down_id == id
	var r := rect
	if pressed:
		r.position.y += 4
	var pulse := sin(_t * 6.0) * 2.0 if enabled and id != "close" else 0.0
	r = r.grow(pulse)
	Art.panel(self, r, col if enabled else Color("a49cb4"), 20, 0.0 if pressed else 6.0, 4)
	var tx := r.get_center().x
	if icon != "":
		Art.icon(self, icon, Vector2(r.position.x + 36, r.get_center().y), 0.48)
		tx += 18
	Art.text(self, label, Vector2(tx, r.get_center().y - 2), 28)
	_buttons.append({"rect": rect, "id": id, "enabled": enabled})


func _draw() -> void:
	_buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.12, 0.6 * _anim))
	var eased := 1.0 - pow(1.0 - _anim, 3.0)
	var r := _panel_rect()
	r.position.y += (1.0 - eased) * 80.0
	Art.panel(self, r, Color("fff4dc"), 28, 8, 5)
	match mode:
		"album": _draw_album(r)
		"offline": _draw_offline(r)
		"prestige": _draw_prestige(r)
	if mode != "offline":
		var close_rect := Rect2(r.end.x - 58, r.position.y - 14, 66, 66)
		Art.panel(self, close_rect, Art.RED, 22, 5, 4)
		Art.icon(self, "close", close_rect.get_center() + Vector2(0, -2), 0.8)
		_buttons.append({"rect": close_rect, "id": "close", "enabled": true})


func _header(r: Rect2, icon: String, title: String, col: Color) -> void:
	var hr := Rect2(r.position.x + 20, r.position.y + 16, r.size.x - 90, 64)
	Art.panel(self, hr, col, 22, 5, 4)
	Art.icon(self, icon, Vector2(hr.position.x + 40, hr.get_center().y), 0.6)
	Art.text(self, title, Vector2(hr.get_center().x + 20, hr.get_center().y), 32)


func _draw_album(r: Rect2) -> void:
	var count := Game.found.size()
	_header(r, "book", "%d / %d" % [count, GameData.item_count()], Color("7b5cff"))
	Art.text(self, "+%d%% coins" % roundi(count * GameData.album_bonus * 100.0), Vector2(r.get_center().x, r.position.y + 104), 24, Art.ORANGE)
	var top := r.position.y + 130
	var rows := GameData.worlds.size()
	var cell := minf((r.size.x - 40) / 5.0, (r.end.y - top - 16) / rows)
	var gx := r.get_center().x - cell * 2.5
	for w in rows:
		var world: WorldData = GameData.worlds[w]
		var reached := w <= Game.world or Game.caps > 0
		for k in mini(world.items.size(), 5):
			var id: String = world.items[k].id
			var cr := Rect2(gx + k * cell + 4, top + w * cell + 4, cell - 8, cell - 8)
			var rarity: int = world.items[k].rarity
			var got := Game.found.has(id)
			var col: Color = GameData.rarities[rarity].color if got else Color("d4c8e0")
			if rarity == 0 and got:
				col = Color("ffe1a8")
			draw_colored_polygon(Art.rrect(cr.grow(3), 14), Art.OL)
			draw_colored_polygon(Art.rrect(cr, 12), col)
			if got:
				Art.item(self, id, cr.get_center(), cell / 105.0)
			elif reached:
				Art.item(self, id, cr.get_center(), cell / 105.0, 0.0, Color("8a7aa3"))
				Art.text(self, "?", cr.get_center(), int(cell * 0.35), Art.WHITE)
			else:
				Art.icon(self, "lock", cr.get_center(), cell / 140.0)


func _draw_offline(r: Rect2) -> void:
	var head := Creatures.raccoon_head(Vector2(0, 0.3), 0.0, Creatures.Mood.HAPPY)
	Art.draw_groups(self, head, Vector2(r.get_center().x, r.position.y + 70), 0.75)
	Art.text(self, "WELCOME BACK!", Vector2(r.get_center().x, r.position.y + 150), 34, Art.ORANGE)
	var line := Vector2(r.get_center().x, r.position.y + 210)
	var amount := Game.fmt(Game.offline_gain)
	var w := Art.text_width(amount, 50)
	Art.icon(self, "coin", line - Vector2(w * 0.5 + 30, 0), 0.7)
	Art.text(self, amount, line + Vector2(20, 0), 50, Art.YELLOW)
	var bw := minf(r.size.x - 80, 300)
	_button(Rect2(r.get_center().x - bw * 0.5, r.end.y - 110, bw, 80), "collect", Color("5ccf4a"), "OK", "coin")


func _draw_prestige(r: Rect2) -> void:
	_header(r, "cap", "GOLDEN CAPS", Color("e09a1f"))
	var gain := Game.caps_gain()
	var c := Vector2(r.get_center().x, r.position.y + 160)
	Art.rays(self, c, 90, 12, _t * 0.6, Color(1, 0.85, 0.3, 0.35))
	Art.icon(self, "cap", c, 1.3 + sin(_t * 4.0) * 0.05)
	Art.text(self, "+%d" % gain, c + Vector2(0, 76), 46, Art.GOLD if gain > 0 else Color("a49cb4"))
	var bonus := roundi(GameData.cap_bonus * 100.0)
	Art.text(self, "Every cap = +%d%% coins forever" % bonus, Vector2(r.get_center().x, r.position.y + 290), 21, Art.OL, HORIZONTAL_ALIGNMENT_CENTER, 0)
	Art.text(self, "You have %d  (+%d%%)" % [Game.caps, Game.caps * bonus], Vector2(r.get_center().x, r.position.y + 322), 21, Color("7b4fe0"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var br := Rect2(r.position.x + 40, r.end.y - 112, r.size.x - 80, 80)
	if gain > 0:
		_button(br, "prestige", Color("5ccf4a"), "START OVER", "arrow")
	else:
		var need := pow(Game.caps_total() + 1.0, 3.0) * GameData.cap_divisor
		_button(br, "none", Color("a49cb4"), "Need " + Game.fmt(need), "coin", false)
