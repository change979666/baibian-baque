class_name SoundManager
extends Node

static var instance: SoundManager

var sfx_player_pool: Array[AudioStreamPlayer] = []
var bgm_player: AudioStreamPlayer

var sfx_deal: AudioStream
var sfx_snap: AudioStream
var sfx_select: AudioStream
var sfx_coin: AudioStream
var sfx_hu: AudioStream
var sfx_gold_chime: AudioStream
var sfx_gold_fly: AudioStream
var bgm_stream: AudioStream

func _init() -> void:
	instance = self

func _ready() -> void:
	_load_or_generate_audio()

	# Create player pool for SFX
	for i in range(10):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_player_pool.append(p)

	# BGM player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = bgm_stream
	bgm_player.volume_db = -8.0
	bgm_player.finished.connect(func():
		if bgm_player and bgm_stream:
			bgm_player.play()
	)
	add_child(bgm_player)
	bgm_player.play()

func play_deal() -> void:
	_play_sfx(sfx_deal, -2.0, randf_range(0.96, 1.04))

func play_snap() -> void:
	_play_sfx(sfx_snap, -1.0, randf_range(0.98, 1.02))

func play_select() -> void:
	_play_sfx(sfx_select, -4.0, 1.0)

func play_coin() -> void:
	_play_sfx(sfx_coin, -2.0, randf_range(0.96, 1.04))

func play_hu() -> void:
	_play_sfx(sfx_hu, 2.0, 1.0)

func play_gold_chime() -> void:
	_play_sfx(sfx_gold_chime, 0.0, randf_range(0.98, 1.02))

func play_gold_fly() -> void:
	_play_sfx(sfx_gold_fly, -1.0, 1.0)

func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	for p in sfx_player_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	# If all busy, use first
	var p0 = sfx_player_pool[0]
	p0.stream = stream
	p0.volume_db = volume_db
	p0.pitch_scale = pitch_scale
	p0.play()

func _load_or_generate_audio() -> void:
	# Try loading authentic imported assets first
	if ResourceLoader.exists("res://assets/audio/bgm.ogg"):
		var ogg = load("res://assets/audio/bgm.ogg") as AudioStreamOggVorbis
		if ogg:
			ogg.loop = true
			bgm_stream = ogg
	if bgm_stream == null:
		_generate_bgm()

	if ResourceLoader.exists("res://assets/audio/sfx_deal.wav"):
		sfx_deal = load("res://assets/audio/sfx_deal.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_snap.wav"):
		sfx_snap = load("res://assets/audio/sfx_snap.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_select.wav"):
		sfx_select = load("res://assets/audio/sfx_select.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_coin.wav"):
		sfx_coin = load("res://assets/audio/sfx_coin.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_hu.wav"):
		sfx_hu = load("res://assets/audio/sfx_hu.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_gold_chime.wav"):
		sfx_gold_chime = load("res://assets/audio/sfx_gold_chime.wav")
	if ResourceLoader.exists("res://assets/audio/sfx_gold_fly.wav"):
		sfx_gold_fly = load("res://assets/audio/sfx_gold_fly.wav")

	_generate_sound_effects_fallbacks()

func _generate_sound_effects_fallbacks() -> void:
	var sample_rate = 22050
	if sfx_deal == null:
		sfx_deal = _create_wav(sample_rate, 0.1, func(t: float, dur: float) -> float:
			var env = sin(t / dur * PI)
			return ((randf() * 2.0 - 1.0) * 0.7 + sin(2.0 * PI * 180.0 * t) * 0.3) * env
		)
	if sfx_snap == null:
		sfx_snap = _create_wav(sample_rate, 0.07, func(t: float, dur: float) -> float:
			return ((1.0 if t < 0.003 else 0.0) * 0.8 + sin(2.0 * PI * 320.0 * t) * 0.6) * exp(-t * 60.0)
		)
	if sfx_select == null:
		sfx_select = _create_wav(sample_rate, 0.04, func(t: float, dur: float) -> float:
			return sin(2.0 * PI * 1400.0 * t) * exp(-t * 90.0)
		)
	if sfx_coin == null:
		sfx_coin = _create_wav(sample_rate, 0.3, func(t: float, dur: float) -> float:
			return (sin(2.0 * PI * 2400.0 * t) * 0.6 + sin(2.0 * PI * 3750.0 * t) * 0.4) * exp(-t * 14.0)
		)
	if sfx_hu == null:
		sfx_hu = _create_wav(sample_rate, 1.4, func(t: float, dur: float) -> float:
			var freqs = [523.25, 659.25, 783.99, 1046.5, 1318.5]
			var delays = [0.0, 0.12, 0.24, 0.36, 0.50]
			var sample = 0.0
			for i in range(freqs.size()):
				var note_t = t - delays[i]
				if note_t >= 0.0:
					sample += (sin(2.0 * PI * freqs[i] * note_t) * 0.6 + sin(2.0 * PI * freqs[i] * 2.0 * note_t) * 0.3) * exp(-note_t * 3.5)
			return clamp(sample * 0.45, -1.0, 1.0)
		)
	if sfx_gold_chime == null:
		sfx_gold_chime = _create_wav(sample_rate, 0.4, func(t: float, dur: float) -> float:
			return (sin(2.0 * PI * 1760.0 * t) * 0.6 + sin(2.0 * PI * 2637.0 * t) * 0.4) * exp(-t * 8.0)
		)
	if sfx_gold_fly == null:
		sfx_gold_fly = _create_wav(sample_rate, 0.5, func(t: float, dur: float) -> float:
			var p = t / dur
			var freq = 400.0 + 800.0 * p
			return sin(2.0 * PI * freq * t) * sin(p * PI) * 0.5
		)



func _generate_bgm() -> void:
	# Soothing oriental Guzheng / harp pentatonic theme (12 seconds loop)
	var sample_rate = 22050
	var duration = 12.0
	# Pentatonic scale in D major (D4, E4, F#4, A4, B4, D5, E5, F#5, A5)
	var penta = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25, 739.99, 880.0]

	# Melodic note sequence [note_idx, start_sec, dur_sec]
	var melody = [
		[0, 0.0, 0.8], [2, 0.5, 0.8], [3, 1.0, 1.0], [4, 1.8, 1.2],
		[5, 3.0, 0.8], [4, 3.5, 0.8], [3, 4.0, 1.2], [2, 5.0, 1.5],
		[3, 6.0, 0.8], [5, 6.5, 0.8], [6, 7.0, 1.2], [7, 8.0, 1.5],
		[5, 9.2, 0.8], [4, 9.8, 0.8], [3, 10.4, 1.0], [0, 11.0, 1.5]
	]

	bgm_stream = _create_wav(sample_rate, duration, func(t: float, dur: float) -> float:
		var sum = 0.0
		# Gentle low pad drone at 146.8Hz (D3)
		var drone = sin(2.0 * PI * 146.83 * t) * 0.08
		drone += sin(2.0 * PI * 220.0 * t) * 0.05
		sum += drone

		for m in melody:
			var note_pitch = penta[m[0]]
			var start_t = m[1]
			var note_t = t - start_t
			if note_t >= 0.0 and note_t < 2.5:
				var env = exp(-note_t * 2.2)
				var tone = sin(2.0 * PI * note_pitch * note_t) * 0.18
				tone += sin(2.0 * PI * note_pitch * 2.0 * note_t) * 0.08
				tone += sin(2.0 * PI * note_pitch * 3.0 * note_t) * 0.03
				sum += tone * env
		return clamp(sum, -1.0, 1.0)
	)
	bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm_stream.loop_begin = 0
	bgm_stream.loop_end = int(sample_rate * duration)

func _create_wav(sample_rate: int, duration: float, gen_func: Callable) -> AudioStreamWAV:
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2) # 16-bit mono

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var val = float(gen_func.call(t, duration))
		var int_val = int(clamp(val * 32767.0, -32768.0, 32767.0))
		# Little endian 16-bit
		byte_array.encode_s16(i * 2, int_val)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav
