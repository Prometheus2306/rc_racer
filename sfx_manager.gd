class_name SFXManager
extends Node

var muted: bool = false
var _motor_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _clips: Dictionary = {}


func _ready() -> void:
	_build_clips()

	_motor_player = AudioStreamPlayer.new()
	_motor_player.stream = _clips["motor_loop"]
	_motor_player.volume_db = -22.0
	_motor_player.pitch_scale = 0.8
	add_child(_motor_player)
	_motor_player.play()

	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		_sfx_players.append(p)


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted


func update_motor(speed_ratio: float, airborne: bool, boosting: bool, active: bool) -> void:
	if _motor_player == null:
		return
	if not active or muted:
		_motor_player.volume_db = -60.0
		return
	var r := clampf(speed_ratio, 0.0, 1.5)
	var target_pitch := 0.72 + r * 1.35 + (0.35 if boosting else 0.0) + (0.18 if airborne else 0.0)
	_motor_player.pitch_scale = lerpf(_motor_player.pitch_scale, target_pitch, 0.18)
	var target_vol := -21.0 + clampf(r, 0.0, 1.0) * 10.5
	_motor_player.volume_db = lerpf(_motor_player.volume_db, target_vol, 0.18)


func play(clip_name: String, pitch: float = 1.0, vol_db: float = -6.5) -> void:
	if muted or not _clips.has(clip_name) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = _clips[clip_name]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


func _build_clips() -> void:
	# 1. Seamless RC electric motor hum (exact integer cycles at 22050 Hz)
	var rate := 22050
	var motor_samples := 2205 # 0.1s -> 10 Hz fundamental grid; 120 Hz = 12 exact cycles
	var motor_buf := PackedByteArray()
	motor_buf.resize(motor_samples * 2)
	for i in range(motor_samples):
		var t := float(i) / float(rate)
		var s := sin(TAU * 120.0 * t) * 0.55 + sin(TAU * 240.0 * t) * 0.28 + sin(TAU * 480.0 * t) * 0.12
		_write_i16(motor_buf, i, s * 0.35)
	var motor_wav := AudioStreamWAV.new()
	motor_wav.format = AudioStreamWAV.FORMAT_16_BITS
	motor_wav.mix_rate = rate
	motor_wav.stereo = false
	motor_wav.data = motor_buf
	motor_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	motor_wav.loop_begin = 0
	motor_wav.loop_end = motor_samples
	_clips["motor_loop"] = motor_wav

	# 2. Race countdown beep & GO!
	_clips["beep_low"] = _synth_tone([440.0], 0.14, 0.45, false)
	_clips["beep_go"] = _synth_tone([880.0, 1174.66], 0.30, 0.55, false)

	# 3. Pickup chime (arpeggio)
	_clips["pickup"] = _synth_arp([523.25, 659.25, 783.99, 1046.5], 0.055, 0.48)

	# 4. Checkpoint & Lap fanfare
	_clips["checkpoint"] = _synth_arp([587.33, 880.0], 0.06, 0.40)
	_clips["lap"] = _synth_arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.07, 0.52)
	_clips["win"] = _synth_arp([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5, 1567.98], 0.085, 0.55)

	# 5. Power-ups & Impacts
	_clips["turbo"] = _synth_sweep(240.0, 920.0, 0.36, 0.50, true)
	_clips["spring"] = _synth_sweep(190.0, 740.0, 0.26, 0.52, false)
	_clips["zap"] = _synth_sweep(980.0, 180.0, 0.28, 0.50, true)
	_clips["oil"] = _synth_sweep(360.0, 140.0, 0.20, 0.45, false)
	_clips["bonk"] = _synth_sweep(210.0, 75.0, 0.16, 0.55, true)


func _synth_tone(freqs: Array, duration: float, amp: float, noisy: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var buf := PackedByteArray()
	buf.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		var env := (1.0 - float(i) / float(count))
		env = env * env
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t)
		s /= maxf(float(freqs.size()), 1.0)
		if noisy:
			s = s * 0.7 + randf_range(-0.3, 0.3)
		_write_i16(buf, i, s * amp * env)
	return _make_wav(buf, rate)


func _synth_arp(notes: Array, step_dur: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var step_samples := int(step_dur * rate)
	var total := step_samples * notes.size()
	var buf := PackedByteArray()
	buf.resize(total * 2)
	for n_idx in range(notes.size()):
		var freq := float(notes[n_idx])
		for j in range(step_samples):
			var idx := n_idx * step_samples + j
			var t := float(idx) / float(rate)
			var local_env := 1.0 - (float(j) / float(step_samples)) * 0.65
			var s := sin(TAU * freq * t) * 0.75 + (1.0 if sin(TAU * freq * t) >= 0.0 else -1.0) * 0.25
			_write_i16(buf, idx, s * amp * local_env)
	return _make_wav(buf, rate)


func _synth_sweep(f0: float, f1: float, duration: float, amp: float, buzz: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var buf := PackedByteArray()
	buf.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var freq := lerpf(f0, f1, u)
		phase += TAU * freq / float(rate)
		var env := 1.0 - u
		var s := sin(phase)
		if buzz:
			s = signf(s) * 0.55 + sin(phase * 2.7) * 0.45
		_write_i16(buf, i, s * amp * env)
	return _make_wav(buf, rate)


func _write_i16(buf: PackedByteArray, sample_idx: int, val: float) -> void:
	var iv := clampi(int(val * 32767.0), -32768, 32767)
	buf.encode_s16(sample_idx * 2, iv)


func _make_wav(buf: PackedByteArray, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = buf
	return wav
