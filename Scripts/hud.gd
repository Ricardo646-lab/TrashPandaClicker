extends Control

# Everything on top of the play area (Scenes/ui/hud.tscn): coin counter,
# next-world bar, buttons, boosts, the quick-buy card, the shop and the popups. Place and
# size the parts in the scene; this script only connects them.

signal travel_pressed
signal popup_action(id: String)
signal play_pressed

@onready var counter: Control = %CoinCounter
@onready var world_bar: Control = %WorldBar
@onready var album_button: IconButton = %AlbumButton
@onready var cap_button: IconButton = %CapButton
@onready var music_button: IconButton = %MusicButton
@onready var sound_button: IconButton = %SoundButton
@onready var shop_button: IconButton = %ShopButton
@onready var boosts: Control = %BoostList
@onready var quick_buy: Control = %QuickBuy
@onready var shop_overlay: Control = %ShopOverlay
@onready var shop: Control = %ShopOverlay.shop
@onready var popup: Control = %Popup
@onready var start_screen: Control = %StartScreen

var started := false
var new_items := 0


func _ready() -> void:
	world_bar.travel_pressed.connect(func() -> void: travel_pressed.emit())
	album_button.pressed.connect(func() -> void:
		new_items = 0
		popup.open("album"))
	cap_button.pressed.connect(func() -> void: popup.open("prestige"))
	music_button.pressed.connect(func() -> void:
		Game.music_on = not Game.music_on
		Sfx.apply_settings()
		Game.save_game())
	sound_button.pressed.connect(func() -> void:
		Game.sound_on = not Game.sound_on
		Sfx.apply_settings()
		Game.save_game())
	shop_button.pressed.connect(func() -> void: shop_overlay.open())
	# The buy card opens the shop at the item it shows.
	quick_buy.opened.connect(func(kind: String, index: int) -> void:
		shop_overlay.open()
		shop.focus(kind, index))
	popup.action.connect(func(id: String) -> void: popup_action.emit(id))
	start_screen.play_pressed.connect(func() -> void:
		started = true
		play_pressed.emit())


# True while a menu covers the game (the shop or a popup).
func menu_open() -> bool:
	return shop_overlay.is_open() or popup.visible


func _process(_delta: float) -> void:
	# Nothing of the HUD shows on the start screen.
	for part in [counter, boosts, album_button, music_button, sound_button, shop_button, quick_buy]:
		part.visible = started
	world_bar.visible = started and Game.has_next_world()
	cap_button.visible = started and Game.prestige_unlocked()

	shop_button.pulse = shop.can_afford_any(0) or shop.can_afford_any(1)
	shop_button.badge = "!" if shop_button.pulse else ""
	cap_button.badge = "!" if Game.caps_gain() > 0 else ""
	album_button.badge = str(new_items) if new_items > 0 else ""
	music_button.dimmed = not Game.music_on
	sound_button.dimmed = not Game.sound_on
