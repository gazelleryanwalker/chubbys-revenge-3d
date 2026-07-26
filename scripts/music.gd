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

const SFX_DUR := {
	"shoot": 0.12, "kill": 0.20, "ram": 0.20, "pickup": 0.22,
	"unlock": 0.45, "knock": 0.42, "waveclear": 0.50,
}

var style := 0
var smp := 0
var player: AudioStreamPlayer
var playback  # AudioStreamGeneratorPlayback or null (headless)
# SFX — second generator player for one-shot synths (headless-safe, null-guarded)
var sfx_player: AudioStreamPlayer
var sfx_playback  # AudioStreamGeneratorPlayback or null (headless)
var sfx_queue: Array = []   # active one-shots: {"name": String, "smp": int}

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
	var gen2 = AudioStreamGenerator.new()
	gen2.mix_rate = MIX
	gen2.buffer_length = 0.2
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = gen2
	sfx_player.volume_db = -3.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback()

func sfx(name: String) -> void:
	# queue a one-shot synth into the sfx generator; no-op when headless
	if sfx_playback == null or not SFX_DUR.has(name):
		return
	sfx_queue.append({"name": name, "smp": 0})
	if sfx_queue.size() > 6:
		sfx_queue.pop_front()

func _sfx_sample(name: String, t: float) -> float:
	match name:
		"shoot":
			# noise burst (0.08s) + low square tail
			var n = randf() * 2.0 - 1.0
			var sq = 0.4 if fmod(t * 90.0, 1.0) < 0.5 else -0.4
			return (n * maxf(0.0, 1.0 - t / 0.08) * 0.7 + sq * maxf(0.0, 1.0 - t / 0.12) * 0.5) * 0.35
		"kill":
			# wet crunch: noise burst with a pitch-dropping tone (0.15s)
			var n = randf() * 2.0 - 1.0
			var f = 300.0 * maxf(0.25, 1.0 - t * 4.0)
			var tone = 0.5 if fmod(t * f, 1.0) < 0.5 else -0.5
			return (n * 0.6 + tone) * maxf(0.0, 1.0 - t / 0.15) * 0.4
		"ram":
			# 60Hz sine thud
			return sin(TAU * 60.0 * t) * maxf(0.0, 1.0 - t / 0.2) * 0.6
		"pickup":
			# two rising sine notes
			var f = 523.25 if t < 0.1 else 783.99
			return sin(TAU * f * t) * maxf(0.0, 1.0 - t / 0.22) * 0.35
		"unlock":
			# three-note fanfare
			var notes = [523.25, 659.25, 783.99]
			var i = clampi(int(t / 0.13), 0, 2)
			return sin(TAU * notes[i] * t) * maxf(0.0, 1.0 - fmod(t, 0.13) / 0.13) * 0.35
		"knock":
			# three 140Hz thuds
			var k = fmod(t, 0.13)
			return sin(TAU * 140.0 * k) * maxf(0.0, 1.0 - k / 0.08) * 0.55
		"waveclear":
			# rising arpeggio
			var notes = [392.0, 523.25, 659.25, 783.99]
			var i = clampi(int(t / 0.11), 0, 3)
			return sin(TAU * notes[i] * t) * maxf(0.0, 1.0 - fmod(t, 0.11) / 0.11) * 0.35
	return 0.0

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
	# SFX one-shots — render into the second generator, drop finished ones
	if sfx_playback != null and not sfx_queue.is_empty():
		var frames2 = sfx_playback.get_frames_available()
		for i in frames2:
			var s2 := 0.0
			for q in sfx_queue:
				s2 += _sfx_sample(q["name"], q["smp"] / MIX)
				q["smp"] += 1
			for j in range(sfx_queue.size() - 1, -1, -1):
				if sfx_queue[j]["smp"] / MIX > SFX_DUR[sfx_queue[j]["name"]]:
					sfx_queue.remove_at(j)
			sfx_playback.push_frame(Vector2(s2, s2))
