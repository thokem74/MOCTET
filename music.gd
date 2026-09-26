extends Node

# Korobeiniki / Tetris Theme A, arranged for the runtime synthesizer.
var player
var generator
var lead_phase = 0.0
var bass_phase = 0.0
var note_index = 0
var note_time = 0.0
var note_length = 0.4
var beat_duration = 0.4
var melody = [
	659.25, 493.88, 523.25, 587.33, 523.25, 493.88, 440.0, 440.0,
	523.25, 659.25, 587.33, 523.25, 493.88, 523.25, 587.33, 659.25,
	523.25, 440.0, 440.0, 0.0,
	587.33, 698.46, 880.0, 783.99, 698.46, 659.25, 523.25, 659.25,
	587.33, 523.25, 493.88, 493.88, 523.25, 587.33, 659.25, 523.25,
	440.0, 440.0,
	659.25, 523.25, 587.33, 493.88, 523.25, 440.0, 415.30, 493.88,
	659.25, 523.25, 587.33, 493.88, 523.25, 659.25, 880.0, 830.61, 0.0
]
var lengths = [
	1.0, 0.5, 0.5, 1.0, 0.5, 0.5, 1.0, 0.5,
	0.5, 1.0, 0.5, 0.5, 1.5, 0.5, 1.0, 1.0,
	1.0, 1.0, 2.0, 0.5,
	1.0, 0.5, 1.0, 0.5, 0.5, 1.5, 0.5, 1.0,
	0.5, 0.5, 1.0, 0.5, 0.5, 1.0, 1.0, 1.0,
	1.0, 2.0,
	2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	2.0, 2.0, 2.0, 2.0, 1.0, 1.0, 2.0, 2.0, 2.0
]
var bass_notes = [164.81, 146.83, 130.81, 123.47, 164.81, 146.83, 110.0, 123.47]

func _ready():
	player = AudioStreamPlayer.new()
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.35
	player.stream = generator
	add_child(player)
	_update_note_length()

func _update_note_length():
	note_length = lengths[note_index] * beat_duration

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
		var bass_hz = bass_notes[int(note_index / 7.0) % bass_notes.size()]
		var attack = minf(1.0, note_time / 0.025)
		var release = minf(1.0, maxf(0.0, (note_length - note_time) / 0.07))
		var envelope = attack * release
		var lead_sample = 0.0
		if melody_hz > 0.0:
			var fundamental = sin(lead_phase * TAU)
			var fifth = 0.18 * sin(lead_phase * TAU * 1.5)
			var octave = 0.12 * sin(lead_phase * TAU * 2.0)
			lead_sample = (fundamental + fifth + octave) * envelope
		var bass_envelope = minf(1.0, note_time / 0.04) * minf(1.0, maxf(0.0, (note_length - note_time) / 0.12))
		var bass_sample = sin(bass_phase * TAU) * bass_envelope
		var sample = lead_sample * 0.032 + bass_sample * 0.016
		stream_playback.push_frame(Vector2(sample, sample))
		lead_phase = fmod(lead_phase + maxf(melody_hz, 1.0) / generator.mix_rate, 1.0)
		bass_phase = fmod(bass_phase + bass_hz / generator.mix_rate, 1.0)
		note_time += 1.0 / generator.mix_rate
		if note_time >= note_length:
			note_time = 0.0
			note_index = (note_index + 1) % melody.size()
			_update_note_length()
