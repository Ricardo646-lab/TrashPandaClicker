extends Control

# Title screen. Gameplay (and the Poki gameplayStart call) begins when the
# player taps PLAY. The first tap also unlocks audio in the browser.

signal play_pressed

var _t := 0.0
var _down := false
var _leaving := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	if _leaving > 0.0:
		_leaving += delta * 4.0
		if _leaving >= 1.0:
			visible = false
	queue_redraw()


func play_rect() -> Rect2:
	var k := clampf(minf(size.x / 720.0, size.y / 620.0), 0.7, 1.3)
	var s := Vector2(320, 110) * k
	return Rect2(Vector2(size.x * 0.5 - s.x * 0.5, size.y * 0.66), s)


func _gui_input(event: InputEvent) -> void:
	if _leaving > 0.0:
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			# Kids may tap anywhere, not only on the button.
			_down = false
			_leaving = 0.01
			play_pressed.emit()
	accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and _leaving <= 0.0 and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_leaving = 0.01
		play_pressed.emit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var fade := 1.0 - clampf(_leaving, 0.0, 1.0)
	var k := clampf(minf(size.x / 720.0, size.y / 620.0), 0.7, 1.3)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.05, 0.18, 0.45 * fade))

	# Wobbly title, one letter at a time.
	var title := "TRASH PANDA"
	var big := int(92 * k)
	var x := size.x * 0.5 - Art.text_width(title, big) * 0.5
	var y := size.y * 0.2
	for i in title.length():
		var ch := title[i]
		var w := Art.text_width(ch, big)
		var bob := sin(_t * 4.0 + i * 0.5) * 8.0 * k
		var col := Art.YELLOW if i < 5 else Color("ff8fb1")
		Art.text(self, ch, Vector2(x + w * 0.5, y + bob), big, Color(col, fade), HORIZONTAL_ALIGNMENT_CENTER, int(big * 0.3))
		x += w
	Art.text(self, "CLICKER", Vector2(size.x * 0.5, y + 86 * k), int(52 * k), Color(Art.WHITE, fade))

	var r := play_rect()
	var pulse := sin(_t * 5.0) * 6.0 * k
	r = r.grow(pulse)
	if _down:
		r.position.y += 5
	Art.panel(self, r, Color(Art.GREEN, fade), r.size.y * 0.4, 0.0 if _down else 8.0, 5)
	Art.icon(self, "arrow", Vector2(r.position.x + 62 * k, r.get_center().y), 0.9 * k, 0.0, fade)
	Art.text(self, "PLAY", Vector2(r.get_center().x + 30 * k, r.get_center().y), int(60 * k), Color(Art.WHITE, fade))
