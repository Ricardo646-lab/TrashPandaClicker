extends Node

# Autoload "Poki": tells the Poki SDK when the player is playing, and
# sends measure(category, what, action) events for the funnel.
# gameLoadingFinished is sent by the HTML shell (full-size.html) once the
# engine has started. The game has no ads.
#
# Events (category / what / action):
#   session      new|returning          load        engine started
#   open         10s|30s|60s            menu|no-tap|tapping   early bounce check
#   start        play                   0-5s|5-10s|10-30s|30s+  PLAY pressed
#   input        first                  mouse|touch|key   first input of any kind
#   tutorial     first-tap|5-taps       complete
#   playtime     30s|1m|2m|...|60m      reached     active play (gameplayStart..Stop)
#   tpm          min-1..min-10,15,20,30 0|1-20|21-60|61-120|121-200|200+   taps in that minute
#   first-buy    <helper or upgrade id> 0-15s|15-30s|30-60s|1-2m|2-5m|5m+
#   helper       <id>                   first       first one bought (first city only)
#                (upgrade and helper ids never overlap: kit, possum.. / claws, paws..)
#   upgrade      <id>                   first       first level bought (first city only)
#   item         <id>                   found       new item in the album
#   world        <id>                   reached
#   prestige     city-<n>               reached
#
# Time buckets for "playtime", "tpm" and "first-buy" count only active play,
# so time in the shop or on the start screen is left out.

const OPEN_CHECKS := [10, 30, 60]
const PLAYTIME_MARKS := [30, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600]
const TPM_MINUTES := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30]

var _playing := false
var _played := false
var _load_ms := 0
var _open_index := 0
var _had_input := false

var _active := 0.0
var _playtime_index := 0
var _minute := 0
var _minute_taps := 0
var _last_taps := 0
var _session_taps := 0

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
	_remember_owned()
	Game.purchased.connect(_on_purchased)
	Game.new_item.connect(_on_new_item)
	var returning := Game.all_time > 0.0 or Game.taps > 0
	measure("session", "returning" if returning else "new", "load")


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
	_played = true
	var sec := _seconds_since_load()
	var bucket := "30s+"
	if sec < 5.0:
		bucket = "0-5s"
	elif sec < 10.0:
		bucket = "5-10s"
	elif sec < 30.0:
		bucket = "10-30s"
	measure("start", "play", bucket)


func _input(event: InputEvent) -> void:
	if _had_input or not event.is_pressed() or event.is_echo():
		return
	var kind := ""
	if event is InputEventScreenTouch:
		kind = "touch"
	elif event is InputEventMouseButton:
		kind = "mouse"
	elif event is InputEventKey:
		kind = "key"
	if kind == "":
		return
	_had_input = true
	measure("input", "first", kind)


func _process(delta: float) -> void:
	_check_open()
	_count_taps()
	_check_progress()
	if not _playing:
		return
	_active += delta
	while _playtime_index < PLAYTIME_MARKS.size() and _active >= PLAYTIME_MARKS[_playtime_index]:
		measure("playtime", _duration_name(PLAYTIME_MARKS[_playtime_index]), "reached")
		_playtime_index += 1
	if _active >= (_minute + 1) * 60.0:
		_minute += 1
		if _minute in TPM_MINUTES:
			measure("tpm", "min-%d" % _minute, _tpm_bucket(_minute_taps))
		_minute_taps = 0


# Early bounce: what the player is doing 10, 30 and 60 seconds after load.
# "menu" = still on the start screen, "no-tap" = played but never tapped
# the trash can (unclear onboarding or the canvas did not get input).
func _check_open() -> void:
	if _open_index >= OPEN_CHECKS.size():
		return
	var mark: int = OPEN_CHECKS[_open_index]
	if _seconds_since_load() < mark:
		return
	var state := "tapping"
	if not _played:
		state = "menu"
	elif _session_taps == 0:
		state = "no-tap"
	measure("open", "%ds" % mark, state)
	_open_index += 1


func _count_taps() -> void:
	var new_taps: int = Game.taps - _last_taps
	if new_taps < 0:
		new_taps = 0
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


# World travel and prestige have no signal, so watch the numbers.
func _check_progress() -> void:
	if Game.caps > _last_caps:
		_last_caps = Game.caps
		_last_world = Game.world
		measure("prestige", "city-%d" % mini(Game.caps, 20), "reached")
	elif Game.world > _last_world:
		_last_world = Game.world
		measure("world", GameData.worlds[Game.world].id, "reached")


func _on_purchased(kind: String, index: int) -> void:
	var id: String = GameData.helpers[index].id if kind == "helper" else GameData.upgrades[index].id
	if _never_bought:
		_never_bought = false
		measure("first-buy", id, _first_buy_bucket(_active))
	# Only the first city, so prestige resets do not count twice.
	if Game.caps > 0 or _owned.has(id):
		return
	_owned[id] = true
	measure(kind, id, "first")


# Helpers and upgrades the player already owns (one save can buy "max",
# so counting the amount bought is not enough).
var _owned := {}

func _remember_owned() -> void:
	for i in GameData.helpers.size():
		if Game.helpers[i] > 0:
			_owned[GameData.helpers[i].id] = true
	for upgrade in GameData.upgrades:
		if Game.level(upgrade.id) > 0:
			_owned[upgrade.id] = true


func _on_new_item(id: String) -> void:
	measure("item", id, "found")


func _seconds_since_load() -> float:
	return (Time.get_ticks_msec() - _load_ms) / 1000.0


func _duration_name(sec: int) -> String:
	return "%ds" % sec if sec < 60 else "%dm" % int(sec / 60.0)


func _tpm_bucket(taps: int) -> String:
	if taps == 0:
		return "0"
	if taps <= 20:
		return "1-20"
	if taps <= 60:
		return "21-60"
	if taps <= 120:
		return "61-120"
	if taps <= 200:
		return "121-200"
	return "200+"


func _first_buy_bucket(sec: float) -> String:
	if sec < 15.0:
		return "0-15s"
	if sec < 30.0:
		return "15-30s"
	if sec < 60.0:
		return "30-60s"
	if sec < 120.0:
		return "1-2m"
	if sec < 300.0:
		return "2-5m"
	return "5m+"
