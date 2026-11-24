extends Node

# Autoload "Poki": tells the Poki SDK when the player is playing, and
# sends measure(category, what, action) events for the funnel.
# gameLoadingFinished is sent by the HTML shell (full-size.html) once the
# engine has started. The game has no ads.
#
# Poki can only build a funnel from a small, fixed set of events, so every
# event below is one fixed name (no ids or buckets). 30 events in total:
#   open      10s | 30s | 60s               reached   still open after load (early bounce)
#   start     play                          press     PLAY tapped
#   tutorial  first-tap | 5-taps            complete
#   shop      first-buy                     complete  first helper or upgrade
#   helper    possum | pigeon               first     2nd and 3rd helper bought (first city)
#   playtime  30s | 1m | 2m | 3m | 5m | 10m | 15m | 20m | 30m  reached
#             active play (gameplayStart..Stop)
#   tpm       min-1 | min-2 | min-3 | min-5 | min-10  fast  60+ taps in that minute of play
#   world     park | pizza | beach | mall | space  reached  (new items per world)
#   album     10-items                      found     10 different items found
#   prestige  city                          reached   first new city
#
# Read in the funnel:
#   early bounce   = 1 - open/10s (or 30s) / loads
#   tapping tempo  = tpm/min-N / playtime/Nm per minute (does it drop?)
#   first purchase = where shop/first-buy falls between the playtime steps
# Playtime counts only active play, not the shop or the start screen.

const OPEN_MARKS := [10, 30, 60]
const PLAYTIME_MARKS := [30, 60, 120, 180, 300, 600, 900, 1200, 1800]
const TPM_MINUTES := [1, 2, 3, 5, 10]
const FAST_TAPS := 60
const HELPER_FIRSTS := ["possum", "pigeon"]
const ALBUM_MARK := 10

var _playing := false
var _load_ms := 0
var _open_index := 0
var _session_taps := 0

var _active := 0.0
var _playtime_index := 0
var _minute := 0
var _minute_taps := 0
var _last_taps := 0

var _never_bought := true
var _last_world := 0
var _last_caps := 0


func _ready() -> void:
	_load_ms = Time.get_ticks_msec()
	# Game is loaded before this autoload, so its save is already read.
	_last_taps = Game.taps
	_last_world = Game.world
	_last_caps = Game.caps
	_never_bought = Game.never_bought()
	Game.purchased.connect(_on_purchased)
	Game.new_item.connect(_on_new_item)
	for i in GameData.helpers.size():
		if Game.helpers[i] > 0:
			_helper_sent[GameData.helpers[i].id] = true


func _sdk():
	if not OS.has_feature("web"):
		return null
	var sdk = get_node_or_null("/root/PokiSDK")
	if sdk == null or not sdk.has_method("gameplayStart") or sdk.get("sdk_handle") == null:
		return null
	return sdk


func measure(category: String, what: String, action: String) -> void:
	if OS.is_debug_build():
		print("[poki] measure %s %s %s" % [category, what, action])
	var sdk = _sdk()
	if sdk and sdk.has_method("measure"):
		sdk.measure(category, what, action)


# Main calls this every frame; the SDK is only told when it changes:
# gameplayStart after PLAY and when a menu closes, gameplayStop when a
# menu (shop or popup) opens.
func set_playing(on: bool) -> void:
	if on == _playing:
		return
	_playing = on
	var sdk = _sdk()
	if sdk:
		if on:
			sdk.gameplayStart()
		else:
			sdk.gameplayStop()


# Main calls this when the player taps PLAY on the start screen.
func play_pressed() -> void:
	measure("start", "play", "press")


func _process(delta: float) -> void:
	_check_open()
	_count_taps()
	_check_world()
	if not _playing:
		return
	_active += delta
	while _playtime_index < PLAYTIME_MARKS.size() and _active >= PLAYTIME_MARKS[_playtime_index]:
		var sec: int = PLAYTIME_MARKS[_playtime_index]
		measure("playtime", "%ds" % sec if sec < 60 else "%dm" % int(sec / 60.0), "reached")
		_playtime_index += 1
	if _active >= (_minute + 1) * 60.0:
		_minute += 1
		if _minute in TPM_MINUTES and _minute_taps >= FAST_TAPS:
			measure("tpm", "min-%d" % _minute, "fast")
		_minute_taps = 0


func _check_open() -> void:
	if _open_index >= OPEN_MARKS.size():
		return
	var mark: int = OPEN_MARKS[_open_index]
	if (Time.get_ticks_msec() - _load_ms) / 1000.0 >= mark:
		measure("open", "%ds" % mark, "reached")
		_open_index += 1


func _count_taps() -> void:
	var new_taps := maxi(Game.taps - _last_taps, 0)
	_last_taps = Game.taps
	if new_taps == 0:
		return
	var before := _session_taps
	_session_taps += new_taps
	_minute_taps += new_taps
	if before == 0:
		measure("tutorial", "first-tap", "complete")
	if before < 5 and _session_taps >= 5:
		measure("tutorial", "5-taps", "complete")


# Travel and prestige have no signal, so watch the numbers. Prestige sets
# the world back to the start; those worlds are not sent again.
func _check_world() -> void:
	if Game.caps > _last_caps:
		if _last_caps == 0:
			measure("prestige", "city", "reached")
		_last_caps = Game.caps
	elif Game.world > _last_world and Game.caps == 0:
		measure("world", GameData.worlds[Game.world].id, "reached")
	_last_world = Game.world


func _on_purchased(kind: String, index: int) -> void:
	if _never_bought:
		_never_bought = false
		measure("shop", "first-buy", "complete")
	# Only in the first city, so a prestige reset does not send it again.
	if kind == "helper" and Game.caps == 0:
		var id: String = GameData.helpers[index].id
		if id in HELPER_FIRSTS and not _helper_sent.has(id) and Game.helpers[index] > 0:
			_helper_sent[id] = true
			measure("helper", id, "first")


# Helpers the player already had when the game loaded are not sent.
var _helper_sent := {}


func _on_new_item(_id: String) -> void:
	if Game.found.size() == ALBUM_MARK:
		measure("album", "%d-items" % ALBUM_MARK, "found")
