class_name IconButton
extends Control

# A big round-cornered button with an icon, a short label and an
# optional red badge. Fires on release, like a normal button.

signal pressed

## Icon name from Art.icon_shapes (for example "book", "cap", "cart").
@export var icon := ""
## Short text under the icon (leave empty for none).
@export var label := ""
@export var color := Color("7b5cff")
## Red circle in the corner ("!" or a number). Set by code.
var badge := ""
var dimmed := false
var pulse := false

var _down := false
var _bump := 0.0
var _t := 0.0
var _last_state := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	_bump = maxf(_bump - delta * 4.0, 0.0)
	# Only redraw when something changed or moves (saves a lot on phones).
	var state := [badge, dimmed, pulse, _down, size, label, icon]
	if pulse or _bump > 0.0 or state != _last_state:
		_last_state = state
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				_bump = 1.0
				Sfx.play("tab", -4.0)
				pressed.emit()
		accept_event()


func _draw() -> void:
	var press := 4.0 if _down else 0.0
	var grow := sin(_bump * PI) * 4.0 + (sin(_t * 6.0) * 2.0 if pulse else 0.0)
	var r := Rect2(Vector2(0, press), size - Vector2(0, 6)).grow(grow)
	var col := color.lerp(Color("8a8499"), 0.6) if dimmed else color
	Art.panel(self, r, col, minf(size.x, size.y) * 0.28, 6.0 - press, 4.0)
	var icon_y := r.get_center().y - (8.0 if label != "" else 0.0)
	Art.icon(self, icon, Vector2(r.get_center().x, icon_y), size.x / 120.0)
	if label != "":
		Art.text(self, label, Vector2(r.get_center().x, r.end.y - size.y * 0.16), int(size.x * 0.22))
	if badge != "":
		var b := Vector2(size.x - 6, 6)
		draw_circle(b, 15, Art.OL, true, -1.0, true)
		draw_circle(b, 12, Art.RED, true, -1.0, true)
		Art.text(self, badge, b, 17, Art.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)
