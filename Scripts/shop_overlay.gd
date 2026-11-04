extends Control

# The shop opens on top of the game (gameplay is "stopped" for Poki while
# it is open). Tap the X or outside the panel to close it.

# The panel size follows the screen (landscape: centred, portrait: from
# the bottom), so Shop and CloseButton are placed by code.

@onready var shop: Control = $Shop
@onready var close_button: IconButton = $CloseButton

var _anim := 0.0
var _down_outside := false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_anim = 0.0
	Sfx.play("whoosh", -6.0)
	_layout()


func close() -> void:
	visible = false


func panel_rect() -> Rect2:
	if size.x >= size.y * 1.05:
		var w := minf(640.0, size.x - 200.0)
		return Rect2((size.x - w) * 0.5, 24, w, size.y - 48)
	var h := size.y * 0.78
	return Rect2(14, size.y - h - 14, size.x - 28, h)


func _close_rect(panel: Rect2) -> Rect2:
	var s := 72.0
	if size.x >= size.y * 1.05:
		return Rect2(panel.end.x + 16, panel.position.y, s, s)
	return Rect2(panel.end.x - s, panel.position.y - s - 14, s, s)


func _layout() -> void:
	var eased := 1.0 - pow(1.0 - _anim, 3.0)
	var r := panel_rect()
	r.position.y += (1.0 - eased) * 90.0
	shop.position = r.position
	shop.size = r.size
	var cr := _close_rect(r)
	close_button.position = cr.position
	close_button.size = cr.size


func _process(delta: float) -> void:
	if not visible:
		return
	_anim = minf(_anim + delta * 6.0, 1.0)
	_layout()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down_outside = true
		elif _down_outside:
			_down_outside = false
			close()
	accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.12, 0.6 * _anim))
	var r := Rect2(shop.position, shop.size)
	draw_colored_polygon(Art.rrect(r.grow(7), 12), Art.OL)
