extends SceneTree

# Renders every sound from sound_synth.gd to res://Sounds/*.wav.
# Run it from the project folder after changing a sound:
#   godot --headless --path . -s res://Scripts/tools/bake_sounds.gd
# then open the editor (or run godot --headless --import) to import them.

const Synth := preload("res://Scripts/tools/sound_synth.gd")
const OUT := "res://Sounds/"


func _initialize() -> void:
	seed(1234)
	var synth := Synth.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sounds: Dictionary = synth.build_sounds()
	for sound in sounds:
		_save(sounds[sound], sound)
	_save(synth.build_music(), "music")
	quit()


func _save(stream: AudioStreamWAV, sound: String) -> void:
	var path := ProjectSettings.globalize_path(OUT + sound + ".wav")
	var err := stream.save_to_wav(path)
	print("%-14s %s" % [sound, "ok" if err == OK else "ERROR %d" % err])
