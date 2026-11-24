extends Node2D

# The root of the game (Scenes/main.tscn). Connects the game events to
# the effects and sounds, and keeps the play area as big as the screen.

@onready var world: Node2D = $World
@onready var fx: Node2D = $Fx
@onready var backdrop: Node2D = $Backdrop
@onready var hud: Control = $UI/HUD


func _ready() -> void:
	world.fx = fx

	world.tapped.connect(_on_tapped)
	world.golden_collected.connect(_on_golden)
	fx.coin_arrived.connect(hud.counter.bump)
	hud.travel_pressed.connect(_on_travel)
	hud.popup_action.connect(_on_popup_action)
	hud.play_pressed.connect(_on_play)
	Game.new_item.connect(_on_new_item)
	Game.rage_started.connect(_on_rage)
	Game.milestone_reached.connect(_on_milestone)
	Game.purchased.connect(_on_purchased)

	get_viewport().size_changed.connect(_layout)
	_layout()
	# gameLoadingFinished is sent by the HTML shell (full-size.html) once
	# the engine has started, so it is not called here.


func _on_play() -> void:
	Poki.play_pressed()
	Sfx.start_music()
	Sfx.play("golden_get", -4.0)
	if Game.offline_gain >= 1.0:
		hud.popup.open("offline")


func _layout() -> void:
	var vp := get_viewport_rect().size
	var scene := Rect2(Vector2.ZERO, vp)
	world.rect = scene
	fx.area = scene


func _process(_delta: float) -> void:
	# Poki: gameplay runs only after PLAY and while no menu is open.
	var playing: bool = hud.started and not hud.menu_open()
	world.active = playing
	Poki.set_playing(playing)
	world.position = fx.position
	backdrop.position = fx.position
	fx.coin_target = hud.counter.coin_global_pos()


func _on_tapped(result: Dictionary, from: Vector2) -> void:
	var s: float = world.scale_factor()
	Sfx.play_dig(Game.rage)
	var best := 0
	var crit := false
	for i in result.finds.size():
		var find: Dictionary = result.finds[i]
		fx.spawn_find(find, from, i, s)
		best = maxi(best, find.rarity)
		crit = crit or find.crit
	fx.fly_coin(from, 3 if best > 0 else 1)
	if best > 0:
		Sfx.play_find(best)
	else:
		Sfx.play("coin", -12.0, randf_range(0.95, 1.1), 0.05)
	if crit:
		Sfx.play("crit", -3.0)
		fx.shake = maxf(fx.shake, 0.5)
	if result.finds.size() > 1:
		fx.float_text("x%d!" % result.finds.size(), from + Vector2(0, -170) * s, Art.GREEN, int(34 * s), 0.7)


func _on_new_item(id: String) -> void:
	hud.new_items += 1
	if GameData.item_rarity(id) < 2:
		Sfx.play("new_item", -4.0)
		fx.float_text("NEW: " + GameData.item_name(id), world.mouth_pos() + Vector2(0, -160) * world.scale_factor(),
			Art.YELLOW, int(28 * world.scale_factor()), 1.2)


func _on_rage() -> void:
	Sfx.play("rage")
	fx.shake = 0.7
	fx.flash = 0.4
	fx.flash_color = Color(1, 0.4, 0.2)
	fx.show_banner("RAGE x" + Game.fmt_small(Game.rage_mult()) + "!", Color("ff5b3a"), "rage", 1.4)


func _on_milestone(index: int) -> void:
	Sfx.play("milestone")
	fx.show_banner("x2 SPEED!", Art.ORANGE, "", 1.6, GameData.helpers[index].name)
	fx.burst(world.helper_pos(index), Art.ORANGE, 24, world.scale_factor())


func _on_purchased(kind: String, index: int) -> void:
	if kind == "helper" and Game.helpers[index] <= 10:
		var s: float = world.scale_factor()
		fx.burst(world.helper_pos(index), Art.YELLOW, 10, s)


func _on_golden(kind: String, pos: Vector2) -> void:
	Sfx.play("golden_get")
	fx.burst(pos, Art.GOLD, 40, world.scale_factor())
	fx.shake = 0.4
	match kind:
		"frenzy":
			Game.start_frenzy(30.0, 7.0)
			fx.show_banner("x7 FRENZY!", Art.GOLD, "golden", 1.8, "30 seconds")
		"storm":
			Game.start_tapstorm(12.0)
			fx.show_banner("TAP x10!", Color("4fa8ff"), "claws", 1.8, "Tap tap tap!")
		_:
			var bonus := Game.lucky_bonus()
			Game.add_coins(bonus)
			fx.fly_coin(pos, 10)
			fx.show_banner("+" + Game.fmt(bonus), Art.YELLOW, "coin", 1.8, "Lucky!")


func _on_travel() -> void:
	if not Game.travel():
		return
	Sfx.play("travel")
	fx.flash = 1.0
	fx.flash_color = Color.WHITE
	fx.confetti(world.rect, 80)
	fx.show_banner(GameData.worlds[Game.world].name.to_upper() + "!", Art.YELLOW, "star", 2.4, "All coins x%d" % int(GameData.world_mult))


func _on_popup_action(id: String) -> void:
	match id:
		"close":
			hud.popup.close()
		"collect":
			_collect_offline(1.0)
		"prestige":
			if Game.prestige():
				hud.popup.close()
				Sfx.play("travel")
				fx.flash = 1.0
				fx.confetti(world.rect, 100)
				fx.show_banner("NEW CITY!", Art.GOLD, "cap", 2.4, "+%d%% coins forever" % roundi(Game.caps * GameData.cap_bonus * 100.0))


func _collect_offline(mult: float) -> void:
	var amount := Game.offline_gain * mult
	Game.collect_offline(mult)
	hud.popup.close()
	Sfx.play("golden_get")
	fx.fly_coin(world.mouth_pos(), 12)
	fx.show_banner("+" + Game.fmt(amount), Art.YELLOW, "coin", 1.8)
