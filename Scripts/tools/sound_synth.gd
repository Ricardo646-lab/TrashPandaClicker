extends RefCounted

# The sound synthesizer. All sound effects and the music are made here in
# code. They are not generated when the game starts (that was slow,
# especially on the web); bake_sounds.gd renders them once to res://Sounds/.
# After changing a sound, run the bake again (see bake_sounds.gd).

const MIX_RATE := 22050
const BPM := 124.0


# --- Sound design -------------------------------------------------------

func build_sounds() -> Dictionary:
	var sounds := {}
	# Trash rustle: a soft thump plus filtered crinkly noise.
	for i in 3:
		sounds["dig_%d" % (i + 1)] = to_stream(mix([
			tone(140.0 + i * 20.0, 60.0, 0.09, 0.45),
			crinkle(0.12 + i * 0.02, 0.35),
		]))
	sounds.coin = to_stream(seq([1568.0, 2093.0], [0.0, 0.05], 0.18, 0.18))
	sounds.tab = to_stream(mix([tone(900.0, 700.0, 0.04, 0.2), noise(0.02, 0.15, 0.5)]))
	sounds.rare = to_stream(seq([784.0, 988.0, 1175.0], [0.0, 0.06, 0.12], 0.25, 0.22))
	sounds.epic = to_stream(seq([659.0, 831.0, 988.0, 1319.0], [0.0, 0.07, 0.14, 0.21], 0.32, 0.22))
	var legend := seq([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0],
			[0.0, 0.07, 0.14, 0.21, 0.28, 0.35], 0.5, 0.2)
	legend = place(legend, mix([soft(1047.0, 0.9, 0.12), soft(1319.0, 0.9, 0.1), soft(1568.0, 0.9, 0.1)]), 0.42)
	sounds.legend = to_stream(legend)
	sounds.crit = to_stream(mix([tone(220.0, 55.0, 0.25, 0.6), noise(0.15, 0.4, 0.3), tone(1760.0, 1760.0, 0.12, 0.08)]))
	sounds.buy = to_stream(place(noise(0.05, 0.3, 0.2), seq([1319.0, 1760.0], [0.0, 0.06], 0.2, 0.2), 0.02))
	sounds.deny = to_stream(seq([220.0, 185.0], [0.0, 0.09], 0.12, 0.25, true))
	sounds.milestone = to_stream(seq([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0],
			[0.0, 0.06, 0.12, 0.18, 0.26, 0.32], 0.3, 0.2))
	sounds.travel = to_stream(seq([392.0, 523.0, 659.0, 784.0, 659.0, 784.0, 1047.0],
			[0.0, 0.12, 0.24, 0.36, 0.52, 0.62, 0.74], 0.6, 0.22))
	var shimmer := PackedFloat32Array()
	for i in 8:
		shimmer = place(shimmer, soft([2093.0, 2637.0, 3136.0, 2637.0][i % 4], 0.2, 0.06), i * 0.05)
	sounds.golden_appear = to_stream(shimmer)
	sounds.golden_get = to_stream(seq([1047.0, 1319.0, 1568.0, 2093.0, 2637.0],
			[0.0, 0.04, 0.08, 0.12, 0.16], 0.35, 0.18))
	sounds.rage = to_stream(mix([tone(110.0, 440.0, 0.6, 0.35, 0.05, 0.8), crinkle(0.6, 0.25), tone(55.0, 110.0, 0.6, 0.4, 0.05, 1.0)]))
	sounds.new_item = to_stream(seq([784.0, 1047.0], [0.0, 0.1], 0.35, 0.22))
	sounds.whoosh = to_stream(noise(0.25, 0.25, 0.75, 1.0))
	return sounds


# Short notes played one after another.
func seq(notes: Array, times: Array, length: float, volume: float, square := false) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for i in notes.size():
		var part := buzz(notes[i], length, volume) if square else soft(notes[i], length, volume)
		samples = place(samples, part, times[i])
	return samples


# Sine with a little third harmonic: round and friendly.
func soft(hz: float, length: float, volume: float) -> PackedFloat32Array:
	return mix([tone(hz, hz, length, volume, 0.004, 2.2), tone(hz * 3.0, hz * 3.0, length * 0.6, volume * 0.15, 0.004, 2.5)])


func buzz(hz: float, length: float, volume: float) -> PackedFloat32Array:
	var count := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += hz / MIX_RATE
		samples[i] = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * pow(1.0 - t, 1.5) * volume * 0.5
	return samples


func crinkle(length: float, volume: float) -> PackedFloat32Array:
	# Noise in random little bursts sounds like a plastic bag.
	var count := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var burst := 0.0
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		if randf() < 0.004:
			burst = randf_range(0.5, 1.0)
		burst *= 0.9985
		filtered += 0.55 * (randf_range(-1.0, 1.0) - filtered)
		samples[i] = filtered * burst * pow(1.0 - t, 1.5) * volume
	return samples


func tone(start_hz: float, end_hz: float, length: float, volume: float,
		attack := 0.005, decay_power := 2.0) -> PackedFloat32Array:
	var count := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(start_hz, end_hz, t) / MIX_RATE
		var envelope := minf(i / (attack * MIX_RATE), 1.0) * pow(1.0 - t, decay_power)
		samples[i] = sin(phase) * envelope * volume
	return samples


func noise(length: float, volume: float, smoothing: float, decay_power := 2.0) -> PackedFloat32Array:
	var count := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		filtered += (1.0 - smoothing) * (randf_range(-1.0, 1.0) - filtered)
		samples[i] = filtered * pow(1.0 - t, decay_power) * volume
	return samples


func mix(parts: Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for part in parts:
		result = place(result, part, 0.0)
	return result


func place(base: PackedFloat32Array, part: PackedFloat32Array, offset: float) -> PackedFloat32Array:
	var start := int(offset * MIX_RATE)
	if base.size() < start + part.size():
		base.resize(start + part.size())
	for i in part.size():
		base[start + i] += part[i]
	return base


func to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


# --- Music --------------------------------------------------------------

# A bouncy 8-bar loop: C - Am - F - G, twice, with a plucky bass, a
# marimba-like melody and soft hi-hats.
func build_music() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var bars := 8
	var total := PackedFloat32Array()
	total.resize(int(bars * 4 * beat * MIX_RATE))

	var roots := [130.81, 110.0, 87.31, 98.0]
	# Melody notes per bar (in semitones above the chord root), 8 eighths.
	var melody := [
		[12, -1, 16, 19, -1, 16, 12, -1],
		[12, -1, 15, 19, -1, 15, 24, -1],
		[12, 16, -1, 19, 21, -1, 19, -1],
		[14, -1, 17, 19, -1, 23, 26, -1],
		[19, -1, 16, 12, -1, 16, 19, 24],
		[15, -1, 19, 24, -1, 19, 15, -1],
		[16, -1, 19, 21, 24, -1, 21, 19],
		[17, -1, 19, 23, -1, 26, -1, -1],
	]
	for bar in bars:
		var root: float = roots[bar % 4]
		var start := bar * 4 * beat
		# Bass: root on 1 and 3, octave up on the "and".
		for b in 4:
			var hz := root * 0.5 if b % 2 == 0 else root
			total = _add(total, pluck(hz, beat * 0.9, 0.32), start + b * beat)
			total = _add(total, pluck(root, beat * 0.4, 0.14), start + (b + 0.5) * beat)
			# Melody.
		for e in 8:
			var semi: int = melody[bar][e]
			if semi >= 0:
				var mhz := root * pow(2.0, semi / 12.0)
				total = _add(total, marimba(mhz, beat * 0.9, 0.16), start + e * beat * 0.5)
			# Hats on the off-beats, kick on 1 and 3.
		for b in 4:
			total = _add(total, noise(0.04, 0.06, 0.1), start + (b + 0.5) * beat)
			if b % 2 == 0:
				total = _add(total, tone(120.0, 40.0, 0.14, 0.35), start + b * beat)
	
	total.resize(int(bars * 4 * beat * MIX_RATE))
	return to_stream(total, true)


func _add(base: PackedFloat32Array, part: PackedFloat32Array, offset: float) -> PackedFloat32Array:
	var start := int(offset * MIX_RATE)
	for i in part.size():
		var j := (start + i) % base.size()
		base[j] += part[i]
	return base


func pluck(hz: float, length: float, volume: float) -> PackedFloat32Array:
	return mix([tone(hz, hz, length, volume, 0.003, 3.0), tone(hz * 2.0, hz * 2.0, length * 0.5, volume * 0.3, 0.003, 3.0)])


func marimba(hz: float, length: float, volume: float) -> PackedFloat32Array:
	return mix([tone(hz, hz, length, volume, 0.002, 4.0), tone(hz * 4.0, hz * 4.0, length * 0.25, volume * 0.2, 0.002, 4.0)])
