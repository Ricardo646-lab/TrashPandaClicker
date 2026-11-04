extends SceneTree

# Balance simulation: a "kid" bot taps TPS times a second, always buys
# what gives the most income per coin and travels as soon as it can.
# It prints when each world is reached, so you can check the pacing after
# changing numbers in Data/. Nothing is saved.
#
#   godot --headless --path . -s res://Scripts/tools/balance_sim.gd -- 4
#   godot --headless --path . -s res://Scripts/tools/balance_sim.gd -- 2.5 noprestige
#
# First argument: taps per second. Add "noprestige" to never prestige.


var TPS := 4.0
var G
var t := 0.0


func _initialize() -> void:
	G = root.get_node("Game")
	G.save_enabled = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		TPS = float(args[0])
	print("=== TPS %.1f ===" % TPS)
	_fresh()
	_run(150.0 * 60.0, args.size() < 2)
	quit()


func _fresh() -> void:
	G.reset_run()
	G.found = {}
	G.all_time = 0.0
	G.caps = 0


func _run(limit: float, allow_prestige: bool) -> void:
	var dt := 1.0 / TPS
	var next_report := 60.0
	var world_seen := 0
	var run_start := 0.0
	while t < limit:
		G.dig()
		G.tick(dt)
		t += dt
		_shop()
		if G.has_next_world() and G.coins >= G.next_world_cost():
			G.travel()
		if G.world != world_seen:
			world_seen = G.world
			print("%6.1f min  >>> WORLD %d %s   (caps gain now %d)" % [t / 60.0, G.world, GameData.worlds[G.world].name, G.caps_gain()])
		# Prestige when it would at least double the caps (and >= 5).
		if allow_prestige and G.prestige_unlocked() and G.caps_gain() >= maxi(5, G.caps) and t - run_start > 600.0:
			print("%6.1f min  *** PRESTIGE +%d caps (had %d)" % [t / 60.0, G.caps_gain(), G.caps])
			G.prestige()
			run_start = t
			world_seen = 0
		if t >= next_report:
			next_report += 60.0 if t < 600 else 300.0
			var tap_income: float = G.expected_tap() * TPS
			print("%6.1f min  w%d coins %s  cps %s  taps/s %s (%.0f%%)  helpers %s  up %s" % [
				t / 60.0, G.world, G.fmt(G.coins), G.fmt(G.cps()), G.fmt(tap_income), 100.0 * tap_income / maxf(tap_income + G.cps(), 1.0),
				str(G.helpers), str(G.upgrades.values())])


func _tap_gain(id: String) -> float:
	var before: float = G.expected_tap()
	G.upgrades[id] += 1
	var after: float = G.expected_tap()
	G.upgrades[id] -= 1
	return (after - before) * TPS


func _shop() -> void:
	for guard in 50:
		var best_ratio := 0.0
		var best := {}
		for i in GameData.helpers.size():
			if not G.helper_unlocked(i):
				break
			var cost: float = G.helper_unit_cost(i, G.helpers[i])
			var gain: float = G.helper_each(i) * G.global_mult()
			if G.milestones_of(G.helpers[i] + 1) > G.milestones_of(G.helpers[i]):
				gain += G.helper_each(i) * G.global_mult() * G.helpers[i]
			# Gold Glove makes helper income count for taps too.
			gain *= 1.0 + 0.01 * G.level("glove") * TPS * 2.0
			if gain / cost > best_ratio:
				best_ratio = gain / cost
				best = {"kind": "h", "i": i, "cost": cost}
		for i in GameData.upgrades.size():
			if G.upgrade_maxed(i) or not G.upgrade_unlocked(i):
				continue
			var cost: float = G.upgrade_cost(i)
			var id: String = GameData.upgrades[i].id
			var gain := 0.0
			if id == "rage":
				gain = G.expected_tap() * TPS * 0.3 * 0.25
			else:
				gain = _tap_gain(id)
			if gain / cost > best_ratio:
				best_ratio = gain / cost
				best = {"kind": "u", "i": i, "cost": cost}
		if best.is_empty() or G.coins < best.cost:
			return
		if best.kind == "h":
			G.buy_helper(best.i, 1)
		else:
			G.buy_upgrade(best.i)
