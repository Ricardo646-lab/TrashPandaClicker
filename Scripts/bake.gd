extends Node

# Autoload "Bake": turns the code drawings into textures, once.
#
# Drawing hundreds of vector shapes every frame is far too slow on the web
# and on phones. So when the game starts, every item, icon, helper and
# raccoon/trash-can part is drawn ONE time into a texture atlas (an
# off-screen SubViewport). After that the game only draws small pieces
# of that texture, which costs almost nothing. World backgrounds are
# baked the same way, one texture per world.
#
# Until the atlas is ready (the first frames) or without a GPU (headless
# tests), Bake.draw() returns false and the caller draws the vectors.

const PAGE := 2048
# Never make render targets bigger or smaller than this (some phones
# can't, and a 0x0 one fails while the page is still loading).
const MIN_TARGET := 32
const MAX_TARGET := 4096
# Wait until the screen size has stopped changing before baking a background.
const SETTLE_TIME := 0.3
const PAD := 4
const SMALL_SCALE := 1.4
const BIG_SCALE := 1.5
# Area (in art units) around 0,0 that small art can use.
const SMALL_BOX := Rect2(-60, -60, 120, 120)
# Radius of the effect sprites (fx_dot, fx_glow, fx_spark) in art units.
const FX_RADIUS := 30.0
const ICONS := ["coin", "claws", "paws", "tail", "eyes", "glove", "rage", "music", "sound",
	"book", "cap", "lock", "close", "arrow", "star", "golden", "cart"]

var atlas: Texture2D
# key -> {"region": Rect2 (pixels in atlas), "box": Rect2 (art units), "scale": float}
var sprites := {}

var _backgrounds := {}
var _bg_pending := {}
var _bg_latest := {}
var _bg_request := {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_bake_atlas.call_deferred()


# Draws a baked sprite. Returns false if it is not baked (yet).
func draw(c: CanvasItem, key: String, pos: Vector2, scale: Vector2, rot := 0.0, modulate := Color.WHITE) -> bool:
	if atlas == null:
		return false
	var s: Dictionary = sprites.get(key, {})
	if s.is_empty():
		return false
	var box: Rect2 = s.box
	if rot == 0.0:
		c.draw_texture_rect_region(atlas, Rect2(pos + box.position * scale, box.size * scale), s.region, modulate)
		return true
	var k: float = s.scale
	c.draw_set_transform(pos, rot, scale / k)
	c.draw_texture_rect_region(atlas, Rect2(box.position * k, box.size * k), s.region, modulate)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


# --- The atlas -------------------------------------------------------------

func _jobs() -> Array:
	var jobs := []
	for world in GameData.worlds:
		for it in world.items:
			jobs.append(_job("item_" + it.id, Art.item_shapes(it.id), SMALL_BOX, SMALL_SCALE))
			jobs.append(_job("itemsil_" + it.id, Art.item_shapes(it.id), SMALL_BOX, SMALL_SCALE, true))
	for h in GameData.helpers:
		jobs.append(_job("helper_" + h.id, Creatures.helper_shapes(h.id), SMALL_BOX, SMALL_SCALE))
		jobs.append(_job("helpersil_" + h.id, Creatures.helper_shapes(h.id), SMALL_BOX, SMALL_SCALE, true))
	for id in ICONS:
		jobs.append(_job("icon_" + id, Art.icon_shapes(id), SMALL_BOX, SMALL_SCALE))
	jobs.append(_job("bin_front", Scenery.bin_front(), Rect2(-128, -214, 256, 222), BIG_SCALE))
	for mood in 4:
		jobs.append(_job("head_%d" % mood, Creatures.raccoon_head(Vector2.ZERO, 0.0, mood, 0.0, Creatures.FUR, Creatures.Part.BASE),
			Rect2(-88, -78, 176, 142), BIG_SCALE))
	jobs.append(_job("tail", Creatures.tail(0.0), Rect2(-26, -146, 100, 172), BIG_SCALE))
	jobs.append(_job("lid", Scenery.lid(), Rect2(-114, -52, 228, 78), BIG_SCALE))
	jobs.append(_job("bin_back", Scenery.bin_back(), Rect2(-108, -214, 216, 48), BIG_SCALE))
	jobs.append(_job("paw", Creatures.raccoon_paw(), Rect2(-26, -20, 52, 40), BIG_SCALE))
	# White effect sprites; they get their colour from modulate. Drawing
	# these instead of circles lets the GPU draw them all in one go.
	var fx_box := Rect2(-32, -32, 64, 64)
	jobs.append(_draw_job("fx_dot", fx_box, func(c: CanvasItem) -> void:
		c.draw_circle(Vector2.ZERO, FX_RADIUS, Color.WHITE, true, -1.0, true)))
	jobs.append(_draw_job("fx_glow", fx_box, func(c: CanvasItem) -> void:
		for i in 16:
			c.draw_circle(Vector2.ZERO, FX_RADIUS * (1.0 - i / 16.0), Color(1, 1, 1, 0.09), true, -1.0, true)))
	jobs.append(_draw_job("fx_spark", fx_box, func(c: CanvasItem) -> void:
		c.draw_colored_polygon(Art.star(Vector2.ZERO, FX_RADIUS, FX_RADIUS * 0.28, 4, 0.0), Color.WHITE)))
	return jobs


func _draw_job(key: String, box: Rect2, drawer: Callable) -> Dictionary:
	return {"key": key, "draw": drawer, "box": box, "scale": 1.0, "sil": false}


func _job(key: String, groups: Array, box: Rect2, scale: float, silhouette := false) -> Dictionary:
	return {"key": key, "groups": groups, "box": box, "scale": scale, "sil": silhouette}


# Simple shelf packing: left to right, then a new row.
func _pack(jobs: Array) -> int:
	var x := PAD
	var y := PAD
	var row := 0
	for job in jobs:
		var px: Vector2 = (job.box.size * job.scale).ceil()
		if x + px.x + PAD > PAGE:
			x = PAD
			y += row + PAD
			row = 0
		job.region = Rect2(Vector2(x, y), px)
		x += int(px.x) + PAD
		row = maxi(row, int(px.y))
	return y + row + PAD


func _bake_atlas() -> void:
	var jobs := _jobs()
	var height := _pack(jobs)
	if height > PAGE:
		push_warning("Bake: atlas is taller than %d px (%d)" % [PAGE, height])
	var painter := Painter.new()
	painter.jobs = jobs
	var tex := await _render(Vector2i(PAGE, mini(height, PAGE)), painter)
	if tex == null:
		return
	for job in jobs:
		sprites[job.key] = {"region": job.region, "box": job.box, "scale": job.scale}
	atlas = tex


# Renders a node once in an off-screen viewport and returns a texture.
func _render(size: Vector2i, node: Node2D) -> Texture2D:
	if size.x < MIN_TARGET or size.y < MIN_TARGET:
		node.free()
		return null
	size = size.clampi(MIN_TARGET, MAX_TARGET)
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(node)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


class Painter extends Node2D:
	var jobs := []

	func _draw() -> void:
		for job in jobs:
			var k: float = job.scale
			var box: Rect2 = job.box
			var region: Rect2 = job.region
			draw_set_transform(region.position - box.position * k, 0.0, Vector2(k, k))
			if job.has("draw"):
				job.draw.call(self)
			else:
				Art.render(self, job.groups, Art.W, Color.WHITE if job.sil else Color(0, 0, 0, 0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Backgrounds -----------------------------------------------------------

# Returns the baked background for this world. If the exact size is not
# baked yet, it returns the last one of this world (draw it stretched) or
# null (then the caller draws the vectors for a moment). Baking waits
# until the screen size has stopped changing.
func background(world: int, size: Vector2) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var key := "%d_%dx%d" % [world, int(size.x), int(size.y)]
	if _backgrounds.has(key):
		return _backgrounds[key]
	if size.x >= MIN_TARGET and size.y >= MIN_TARGET and _bg_request.get("key", "") != key:
		_bg_request = {"key": key, "world": world, "size": size, "time": 0.0}
	return _bg_latest.get(world)


func _process(delta: float) -> void:
	if _bg_request.is_empty():
		return
	_bg_request.time += delta
	var key: String = _bg_request.key
	if _bg_request.time < SETTLE_TIME or _bg_pending.has(key) or _backgrounds.has(key):
		return
	_bg_pending[key] = true
	_bake_background(_bg_request.world, _bg_request.size, key)
	_bg_request = {}


func _bake_background(world: int, size: Vector2, key: String) -> void:
	var painter := BackgroundPainter.new()
	painter.world = world
	painter.area = Rect2(Vector2.ZERO, size)
	var tex := await _render(Vector2i(size), painter)
	_bg_pending.erase(key)
	if tex:
		# Keep only a few, so rotating the phone doesn't fill the memory.
		if _backgrounds.size() > 4:
			_backgrounds.clear()
		_backgrounds[key] = tex
		_bg_latest[world] = tex


class BackgroundPainter extends Node2D:
	var world := 0
	var area := Rect2()

	func _draw() -> void:
		Scenery.background(self, world, area, 0.0)
