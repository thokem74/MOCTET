extends Node

const MUSIC_PATH := "res://audio/korobeiniki_arcade.ogg"
const MUSIC_BUS := "Music"
const MUSIC_VOLUME_DB := -6.0

var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var fallback_active := false
var enabled := true
var fallback_phase := 0.0
var fallback_note := 0
var fallback_notes := [
	659.25, 493.88, 523.25, 587.33, 523.25, 493.88, 440.0, 440.0,
	523.25, 659.25, 587.33, 523.25, 493.88, 523.25, 587.33, 659.25,
	523.25, 440.0, 440.0, 0.0
]
var fallback_lengths := [1.0, 0.5, 0.5, 1.0, 0.5, 0.5, 1.0, 0.5, 0.5, 1.0, 0.5, 0.5, 1.5, 0.5, 1.0, 1.0, 1.0, 1.0, 2.0, 0.5]
var fallback_note_time := 0.0
var fallback_note_length := 0.4

func _ready() -> void:
	_ensure_music_bus()
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.volume_db = MUSIC_VOLUME_DB
	player.bus = MUSIC_BUS
	add_child(player)
	var imported_stream = load(MUSIC_PATH)
	if imported_stream is AudioStream:
		if imported_stream is AudioStreamOggVorbis:
			imported_stream.loop = true
		player.stream = imported_stream
		fallback_active = false
	else:
		_setup_fallback_generator()
	fallback_note_length = fallback_lengths[0] * 0.4

func _ensure_music_bus() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, MUSIC_BUS)
	AudioServer.set_bus_volume_db(bus_index, MUSIC_VOLUME_DB)

func _setup_fallback_generator() -> void:
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.5
	player.stream = generator
	fallback_active = true

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and player != null and player.playing:
		player.stop()

func _reset_fallback() -> void:
	fallback_phase = 0.0
	fallback_note = 0
	fallback_note_time = 0.0
	fallback_note_length = fallback_lengths[0] * 0.4

func tick(_delta: float, active: bool) -> void:
	if player == null:
		return
	if not enabled or not active:
		if player.playing:
			player.stop()
		if fallback_active:
			_reset_fallback()
		return
	if not player.playing:
		player.play()
	if not fallback_active:
		return
	var playback = player.get_stream_playback()
	if playback == null:
		return
	var available: int = playback.get_frames_available()
	for _index in range(available):
		var hz: float = fallback_notes[fallback_note]
		var envelope := minf(1.0, fallback_note_time / 0.012) * minf(1.0, maxf(0.0, (fallback_note_length - fallback_note_time) / 0.05))
		var sample := 0.0
		if hz > 0.0:
			sample = (sin(fallback_phase * TAU) + sin(fallback_phase * TAU * 3.0) / 3.0 + sin(fallback_phase * TAU * 5.0) / 5.0) * envelope * 0.05
		playback.push_frame(Vector2(sample, sample))
		fallback_phase = fmod(fallback_phase + maxf(hz, 1.0) / generator.mix_rate, 1.0)
		fallback_note_time += 1.0 / generator.mix_rate
		if fallback_note_time >= fallback_note_length:
			fallback_note = (fallback_note + 1) % fallback_notes.size()
			fallback_note_time = 0.0
			fallback_note_length = fallback_lengths[fallback_note] * 0.4
