extends Node

# Autoload "Sfx": plays the sound effects and the music. The sounds are
# made in code (Scripts/tools/sound_synth.gd) and baked to res://Sounds/,
# so the game does not have to generate them every time it starts.

const PLAYER_COUNT := 12
const SOUND_NAMES := ["dig_1", "dig_2", "dig_3", "pop", "coin", "tab", "rare", "epic", "legend",
	"crit", "buy", "deny", "milestone", "travel", "golden_appear", "golden_get", "rage",
	"new_item", "whoosh"]

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_player: AudioStreamPlayer
var _last_play := {}
var _muted := false


func _ready() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -9.0
	add_child(music_player)
	for sound in SOUND_NAMES:
		sounds[sound] = load("res://Sounds/%s.wav" % sound)
	music_player.stream = load("res://Sounds/music.wav")
	apply_settings()


# Called when the player presses PLAY (browsers only allow audio after a tap).
func start_music() -> void:
	if not music_player.playing:
		music_player.play()


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Game.music_on)
	_muted = not Game.sound_on


func play(sound: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.0) -> void:
	if _muted or not sounds.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - _last_play.get(sound, -10.0) < min_gap:
		return
	_last_play[sound] = now
	var player := players[next_player]
	next_player = (next_player + 1) % PLAYER_COUNT
	player.stream = sounds[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_dig(combo: float) -> void:
	# Pitch goes up while the rage meter fills, so fast tapping "climbs".
	var pitch := randf_range(0.9, 1.1) + combo * 0.35
	play(["dig_1", "dig_2", "dig_3"].pick_random(), -3.0, pitch)
	play("pop", -8.0, pitch)


func play_find(rarity: int) -> void:
	match rarity:
		1: play("rare", -3.0)
		2: play("epic", -2.0)
		3: play("legend", 0.0)
