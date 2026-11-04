extends Node

# Autoload "Game": all game data and rules. Visual nodes read from here
# and call its functions; they never change the numbers themselves.

signal purchased(kind: String, index: int)
signal milestone_reached(helper_index: int)
signal new_item(id: String)
signal rage_started

const SAVE_PATH := "user://trashpanda.cfg"
const OFFLINE_RATE := 0.5
const OFFLINE_MAX_SEC := 4.0 * 3600.0
const RAGE_DECAY := 0.22
const AUTOSAVE_SEC := 5.0

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var coins := 0.0
var all_time := 0.0
var taps := 0
var helpers: Array[int] = []
var upgrades := {}
var world := 0
var found := {}
var caps := 0
var music_on := true
var sound_on := true
var tutorial_done := false

# Temporary boosts (seconds left).
var frenzy_time := 0.0
var frenzy_mult := 7.0
var tapstorm_time := 0.0
var rage_time := 0.0
var rage := 0.0

# Coins earned while away; main shows a popup to collect them.
var offline_gain := 0.0
var offline_seconds := 0.0

var _save_timer := 0.0
# Tests and the balance simulation turn this off.
var save_enabled := true


func _ready() -> void:
	reset_run()
	load_game()


func reset_run() -> void:
	coins = 0.0
	taps = 0
	world = 0
	helpers.clear()
	for i in GameData.helpers.size():
		helpers.append(0)
	upgrades.clear()
	for upgrade in GameData.upgrades:
		upgrades[upgrade.id] = 0
	frenzy_time = 0.0
	tapstorm_time = 0.0
	rage_time = 0.0
	rage = 0.0


func _process(delta: float) -> void:
	tick(delta)
	_save_timer += delta
	if _save_timer >= AUTOSAVE_SEC:
		save_game()


func tick(delta: float) -> void:
	add_coins(cps() * delta)

	frenzy_time = maxf(frenzy_time - delta, 0.0)
	tapstorm_time = maxf(tapstorm_time - delta, 0.0)
	if rage_time > 0.0:
		rage_time = maxf(rage_time - delta, 0.0)
		rage = rage_time / rage_duration()
	else:
		rage = maxf(rage - RAGE_DECAY * delta, 0.0)


func add_coins(amount: float) -> void:
	coins += amount
	all_time += amount


# --- Income ---------------------------------------------------------------

func level(upgrade_id: String) -> int:
	return upgrades.get(upgrade_id, 0)


func global_mult() -> float:
	var album := 1.0 + GameData.album_bonus * found.size()
	var cap := 1.0 + GameData.cap_bonus * caps
	return pow(GameData.world_mult, world) * album * cap


# Temporary multipliers that count for both tapping and helpers.
func boost_mult() -> float:
	var mult := 1.0
	if frenzy_time > 0.0:
		mult *= frenzy_mult
	return mult


func milestones_of(count: int) -> int:
	var reached := 0
	for m in GameData.milestones:
		if count >= m:
			reached += 1
	return reached


# The next milestone above count, and the one before it (for a bar).
func milestone_range(count: int) -> Vector2i:
	var previous := 0
	for m in GameData.milestones:
		if count < m:
			return Vector2i(previous, m)
		previous = m
	return Vector2i(previous, previous + 100 * (1 + floori((count - previous) / 100.0)))


func helper_each(index: int) -> float:
	return GameData.helpers[index].cps * pow(2.0, milestones_of(helpers[index]))


# Income per second without temporary boosts (used for offline income).
func base_cps() -> float:
	var total := 0.0
	for i in helpers.size():
		total += helper_each(i) * helpers[i]
	return total * global_mult()


func cps() -> float:
	return base_cps() * boost_mult()


func claw_power() -> float:
	var claws := level("claws")
	return (1.0 + claws) * pow(2.0, floori(claws / 25.0))


# Coins for one common find, before rarity, crit and rage.
func tap_value() -> float:
	var value := claw_power() * global_mult() + base_cps() * 0.01 * level("glove")
	value *= boost_mult()
	if tapstorm_time > 0.0:
		value *= 10.0
	return value


func double_chance() -> float:
	return 0.03 * level("paws")


func triple_chance() -> float:
	return 0.1 if upgrade_maxed(1) else 0.0


func luck_mult() -> float:
	return 1.0 + 0.1 * level("tail")


func crit_chance() -> float:
	return 0.01 + 0.005 * level("eyes")


func rage_mult() -> float:
	return 3.0 + 0.25 * level("rage")


func rage_duration() -> float:
	return 8.0 + level("rage")


func rage_per_tap() -> float:
	return 0.07


# Average coins for one tap (rarity, crits and extra finds included,
# rage left out). Used by tools/balance_sim.gd.
func expected_tap() -> float:
	var total := 0.0
	var value := 0.0
	for i in GameData.rarities.size():
		var w: float = GameData.rarities[i].weight * (luck_mult() if i > 0 else 1.0)
		total += w
		value += w * GameData.rarities[i].mult
	var finds := 1.0 + double_chance() + triple_chance()
	return tap_value() * value / total * (1.0 + crit_chance() * 9.0) * finds


# --- Digging ----------------------------------------------------------------

func roll_rarity() -> int:
	var weights: Array[float] = []
	var total := 0.0
	for i in GameData.rarities.size():
		var w: float = GameData.rarities[i].weight
		if i > 0:
			w *= luck_mult()
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0


# A random item of this rarity from the current world.
func pick_item(rarity: int) -> String:
	var options: Array[String] = []
	var fallback := ""
	for it in GameData.worlds[world].items:
		if it.rarity == rarity:
			options.append(it.id)
		elif fallback == "" or it.rarity < rarity:
			fallback = it.id
	return options.pick_random() if not options.is_empty() else fallback


# One tap on the trash can. Returns what was found, for the visuals.
func dig() -> Dictionary:
	taps += 1
	var count := 1
	if randf() < double_chance():
		count += 1
	if randf() < triple_chance():
		count += 1

	var finds := []
	var total := 0.0
	var base := tap_value()
	if rage_time > 0.0:
		base *= rage_mult()

	for i in count:
		var rarity := roll_rarity()
		var id := pick_item(rarity)
		var crit := randf() < crit_chance()
		var value: float = base * GameData.rarities[rarity].mult
		if crit:
			value *= 10.0
		var is_new := not found.has(id)
		found[id] = found.get(id, 0) + 1
		finds.append({"id": id, "rarity": rarity, "value": value, "crit": crit, "new": is_new})
		total += value
		if is_new:
			new_item.emit(id)

	add_coins(total)

	if rage_time <= 0.0:
		rage = minf(rage + rage_per_tap(), 1.0)
		if rage >= 1.0:
			rage_time = rage_duration()
			rage_started.emit()

	return {"finds": finds, "total": total}


# --- Shop ---------------------------------------------------------------------

func helper_unit_cost(index: int, owned: int) -> float:
	return GameData.helpers[index].cost * pow(GameData.helper_growth, owned)


func helper_cost(index: int, amount: int) -> float:
	var r := GameData.helper_growth
	return helper_unit_cost(index, helpers[index]) * (pow(r, amount) - 1.0) / (r - 1.0)


func helper_max_affordable(index: int) -> int:
	var r := GameData.helper_growth
	var first := helper_unit_cost(index, helpers[index])
	if coins < first:
		return 0
	return int(floor(log(coins * (r - 1.0) / first + 1.0) / log(r)))


# amount < 0 means "as many as possible".
func helper_buy_amount(index: int, amount: int) -> int:
	if amount < 0:
		return maxi(helper_max_affordable(index), 1)
	return amount


func buy_helper(index: int, amount: int) -> bool:
	if not helper_unlocked(index):
		return false
	amount = helper_buy_amount(index, amount)
	var cost := helper_cost(index, amount)
	if coins < cost:
		return false
	var before := milestones_of(helpers[index])
	coins -= cost
	helpers[index] += amount
	purchased.emit("helper", index)
	if milestones_of(helpers[index]) > before:
		milestone_reached.emit(index)
	save_game()
	return true


# A helper can be bought once you own HELPER_UNLOCK of the one before it.
func helper_unlocked(index: int) -> bool:
	return index == 0 or helpers[index - 1] >= GameData.helper_unlock or helpers[index] > 0


func upgrade_cost(index: int) -> float:
	var upgrade: UpgradeData = GameData.upgrades[index]
	return upgrade.cost * pow(upgrade.growth, level(upgrade.id))


func upgrade_maxed(index: int) -> bool:
	var upgrade: UpgradeData = GameData.upgrades[index]
	return upgrade.max_level > 0 and level(upgrade.id) >= upgrade.max_level


func upgrade_levels_left(index: int) -> int:
	var upgrade: UpgradeData = GameData.upgrades[index]
	if upgrade.max_level <= 0:
		return 1000000
	return maxi(upgrade.max_level - level(upgrade.id), 0)


# Cost of the next n levels together.
func upgrade_cost_n(index: int, n: int) -> float:
	var g: float = GameData.upgrades[index].growth
	return upgrade_cost(index) * (pow(g, n) - 1.0) / (g - 1.0)


func upgrade_max_affordable(index: int) -> int:
	var g: float = GameData.upgrades[index].growth
	var first := upgrade_cost(index)
	if coins < first:
		return 0
	var n := int(floor(log(coins * (g - 1.0) / first + 1.0) / log(g)))
	return mini(n, upgrade_levels_left(index))


# amount < 0 means "as many as possible". Never more than the levels left.
func upgrade_buy_amount(index: int, amount: int) -> int:
	if amount < 0:
		return maxi(upgrade_max_affordable(index), 1)
	return maxi(mini(amount, upgrade_levels_left(index)), 1)


func buy_upgrade(index: int, amount := 1) -> bool:
	if upgrade_maxed(index) or not upgrade_unlocked(index):
		return false
	var n := upgrade_buy_amount(index, amount)
	var cost := upgrade_cost_n(index, n)
	if coins < cost:
		return false
	coins -= cost
	var id: String = GameData.upgrades[index].id
	upgrades[id] += n
	purchased.emit("upgrade", index)
	save_game()
	return true


# An upgrade can be bought once the one above it has the "unlock" level.
func upgrade_unlocked(index: int) -> bool:
	if index == 0 or level(GameData.upgrades[index].id) > 0:
		return true
	return level(GameData.upgrades[index - 1].id) >= GameData.upgrades[index].unlock


# Short text for what you still need before something unlocks.
func unlock_hint(kind: String, index: int) -> String:
	if kind == "helper":
		return "Need %d %s" % [GameData.helper_unlock, GameData.helpers[index - 1].name]
	return "Need %s Lv %d" % [GameData.upgrades[index - 1].name, GameData.upgrades[index].unlock]


# Short text for what you get after buying the next level.
func upgrade_effect(index: int) -> String:
	var next := level(GameData.upgrades[index].id) + 1
	match GameData.upgrades[index].id:
		"claws": return "+%s per tap" % fmt(claw_step())
		"paws": return "%d%% double find" % (3 * next)
		"tail": return "x%s rare items" % fmt_small(1.0 + 0.1 * next)
		"eyes": return "%s%% for x10" % fmt_small(1.0 + 0.5 * next)
		"glove": return "tap +%d%% of /s" % next
		"rage": return "x%s for %ds" % [fmt_small(3.0 + 0.25 * next), 8 + next]
	return ""


# How much one more claw level adds to a common tap (shown in the shop).
func claw_step() -> float:
	var claws := level("claws")
	var next := (2.0 + claws) * pow(2.0, floori((claws + 1) / 25.0))
	return (next - claw_power()) * global_mult()


# --- Worlds & prestige ------------------------------------------------------------

func has_next_world() -> bool:
	return world + 1 < GameData.worlds.size()


func next_world_cost() -> float:
	if not has_next_world():
		return INF
	return GameData.worlds[world + 1].cost


func travel() -> bool:
	if not has_next_world() or coins < next_world_cost():
		return false
	coins -= next_world_cost()
	world += 1
	save_game()
	return true


func caps_total() -> int:
	return int(floor(pow(all_time / GameData.cap_divisor, 1.0 / 3.0) + 0.0001))


func caps_gain() -> int:
	return maxi(caps_total() - caps, 0)


func prestige_unlocked() -> bool:
	return world >= GameData.prestige_world or caps > 0


func prestige() -> bool:
	if caps_gain() < 1:
		return false
	caps += caps_gain()
	reset_run()
	save_game()
	return true


# --- Boosts ---------------------------------------------------------------------

func start_frenzy(seconds: float, mult: float) -> void:
	frenzy_time = seconds
	frenzy_mult = mult


func start_tapstorm(seconds: float) -> void:
	tapstorm_time = seconds


func lucky_bonus() -> float:
	# About two minutes of income, but never less than 50 taps.
	return maxf(cps() * 120.0, tap_value() * 50.0)


func collect_offline(mult: float) -> void:
	add_coins(offline_gain * mult)
	offline_gain = 0.0
	save_game()


# --- Save -------------------------------------------------------------------------

func save_game() -> void:
	_save_timer = 0.0
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "all_time", all_time)
	cfg.set_value("game", "taps", taps)
	cfg.set_value("game", "helpers", Array(helpers))
	cfg.set_value("game", "upgrades", upgrades)
	cfg.set_value("game", "world", world)
	cfg.set_value("game", "found", found)
	cfg.set_value("game", "caps", caps)
	cfg.set_value("game", "time", Time.get_unix_time_from_system())
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sound", sound_on)
	cfg.set_value("settings", "tutorial_done", tutorial_done)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("game", "coins", 0.0)
	all_time = cfg.get_value("game", "all_time", 0.0)
	taps = cfg.get_value("game", "taps", 0)
	var saved_helpers: Array = cfg.get_value("game", "helpers", [])
	for i in mini(saved_helpers.size(), helpers.size()):
		helpers[i] = saved_helpers[i]
	var saved_upgrades: Dictionary = cfg.get_value("game", "upgrades", {})
	for id in saved_upgrades:
		if upgrades.has(id):
			upgrades[id] = saved_upgrades[id]
	world = clampi(cfg.get_value("game", "world", 0), 0, GameData.worlds.size() - 1)
	found = cfg.get_value("game", "found", {})
	caps = cfg.get_value("game", "caps", 0)
	music_on = cfg.get_value("settings", "music", true)
	sound_on = cfg.get_value("settings", "sound", true)
	tutorial_done = cfg.get_value("settings", "tutorial_done", false)

	var saved_time: float = cfg.get_value("game", "time", 0.0)
	var away := Time.get_unix_time_from_system() - saved_time
	if saved_time > 0.0 and away > 60.0:
		offline_seconds = minf(away, OFFLINE_MAX_SEC)
		offline_gain = base_cps() * offline_seconds * OFFLINE_RATE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		save_game()


# --- Number formatting ------------------------------------------------------------

# 999, 1.23K, 12.3K, 123K, 1.23M ...
func fmt(value: float) -> String:
	if is_inf(value) or is_nan(value):
		return "-"
	if value < 1000.0:
		if value < 10.0 and absf(value - roundf(value)) > 0.05:
			return "%.1f" % value
		return str(int(floor(value)))
	var tier := int(floor(log(value) / log(1000.0)))
	var scaled := value / pow(1000.0, tier)
	if scaled >= 999.5:
		scaled /= 1000.0
		tier += 1
	var suffix := _suffix(tier)
	if scaled < 10.0:
		return "%.2f%s" % [floor(scaled * 100.0) / 100.0, suffix]
	if scaled < 100.0:
		return "%.1f%s" % [floor(scaled * 10.0) / 10.0, suffix]
	return "%d%s" % [int(floor(scaled)), suffix]


func fmt_small(value: float) -> String:
	if absf(value - roundf(value)) < 0.01:
		return str(roundi(value))
	if absf(value * 10.0 - roundf(value * 10.0)) < 0.01:
		return "%.1f" % value
	return "%.2f" % value


func _suffix(tier: int) -> String:
	if tier < SUFFIXES.size():
		return SUFFIXES[tier]
	# After Dc: aa, ab, ac ...
	var n := tier - SUFFIXES.size()
	var a := "abcdefghijklmnopqrstuvwxyz"
	return a[floori(n / 26.0) % 26] + a[n % 26]
