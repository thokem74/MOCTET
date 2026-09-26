extends Node

var player
var generator
var phase = 0.0
var frequency = 440.0
var notes = [659.25, 493.88, 523.25, 587.33, 523.25, 493.88, 440.0, 440.0, 523.25, 659.25]
var note_index = 0
var note_time = 0.0

func _ready():
	player = AudioStreamPlayer.new()
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.5
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
	for index in range(mini(available, 256)):
		var sample = sin(phase * TAU) * 0.06
		stream_playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + frequency / generator.mix_rate, 1.0)
		note_time += 1.0 / generator.mix_rate
		if note_time >= 0.18:
			note_time = 0.0
			note_index = (note_index + 1) % notes.size()
			frequency = notes[note_index]
