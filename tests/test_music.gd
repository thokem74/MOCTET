extends RefCounted

func test_arcade_music_resource() -> void:
	var stream = load("res://audio/korobeiniki_arcade.ogg")
	assert(stream is AudioStreamOggVorbis)
	assert(stream.get_length() > 20.0)
	assert(stream.get_length() < 30.0)

func test_arcade_music_resource_type() -> void:
	var stream = load("res://audio/korobeiniki_arcade.ogg")
	assert(stream.get_class() == "AudioStreamOggVorbis")
