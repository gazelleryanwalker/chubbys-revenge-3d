extends Node
## Procedural music: 3 rotating styles by level (rage funk / nu chug / thrash gallop).
## AudioStreamGenerator fed frame-by-frame in _process. Headless-safe: every
## playback access is null-guarded (dummy audio driver returns null playback).

const MIX := 22050.0
const VOL := 0.12
const ROOTS := [73.42, 65.41, 82.41]     # D2 rage / C2 nu / E2 thrash
const STEP_DUR := [0.24, 0.50, 0.14]     # seconds per 8th-step, per style
const PATTERNS := [
	[0, 12, 0, 12, 0, 12, 7, 10],   # rage — funky octave bass riff
	[0, 0, 1, 0, 0, 6, 1, 0],       # nu — slow dissonant chug
	[0, 0, 12, 0, 0, 0, 7, 0],      # thrash — fast gallop
]

var style := 0
var smp := 0
var player: AudioStreamPlayer
var playback  # AudioStreamGeneratorPlayback or null (headless)

func _ready() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = MIX
	gen.buffer_length = 0.3
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = -6.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func set_level(wave: int) -> void:
	style = maxi(0, wave - 1) % 3

func _process(_delta: float) -> void:
	if playback == null:
		return
	var frames = playback.get_frames_available()
	if frames <= 0:
		return
	var sd = STEP_DUR[style]
	var root = ROOTS[style]
	var pat = PATTERNS[style]
	for i in frames:
		var step_f = smp / (MIX * sd)
		var st = int(step_f) % 8
		var step_pos = fmod(step_f, 1.0)
		var freq = root * pow(2.0, pat[st] / 12.0)
		var ph = fmod(smp * freq / MIX, 1.0)
		# square bass with per-step decay envelope
		var env = 1.0 - step_pos * 0.6
		var bass = (0.6 if ph < 0.5 else -0.6) * env
		# kick: short sine thump on steps 0 and 4
		var kick = 0.0
		if st % 4 == 0:
			kick = sin(TAU * 55.0 * step_pos * sd) * maxf(0.0, 1.0 - step_pos * 4.0)
		var s = (bass * 0.7 + kick * 0.9) * VOL
		playback.push_frame(Vector2(s, s))
		smp += 1
