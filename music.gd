extends Node

var player
var generator
var lead_phase = 0.0
var bass_phase = 0.0
var note_index = 0
var note_time = 0.0
var note_length = 0.24
var melody = [659.25, 493.88, 523.25, 587.33, 523.25, 493.88, 440.0, 440.0, 523.25, 659.25, 587.33, 523.25, 493.88, 0.0, 523.25, 587.33]
var bass = [110.0, 146.83, 130.81, 98.0]

func _ready():
	player = AudioStreamPlayer.new()
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.35
	player.stream = generator
	add_child(player)

func tick(_delta, active):
	if not active:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	var stream_playback = player.get_stream_playback()
	if stream_playback == null:
		return
	var available = stream_playback.get_frames_available()
	for index in range(available):
		var melody_hz = melody[note_index]
		var bass_hz = bass[int(note_index / 4) % bass.size()]
		var attack = minf(1.0, note_time / 0.025)
		var release = minf(1.0, maxf(0.0, (note_length - note_time) / 0.055))
		var envelope = attack * release
		var lead_sample = 0.0
		if melody_hz > 0.0:
			lead_sample = (sin(lead_phase * TAU) + 0.28 * sin(lead_phase * TAU * 2.0)) * envelope
		var bass_sample = sin(bass_phase * TAU) * envelope
		var sample = lead_sample * 0.035 + bass_sample * 0.018
		stream_playback.push_frame(Vector2(sample, sample))
		lead_phase = fmod(lead_phase + maxf(melody_hz, 1.0) / generator.mix_rate, 1.0)
		bass_phase = fmod(bass_phase + bass_hz / generator.mix_rate, 1.0)
		note_time += 1.0 / generator.mix_rate
		if note_time >= note_length:
			note_time = 0.0
			note_index = (note_index + 1) % melody.size()
