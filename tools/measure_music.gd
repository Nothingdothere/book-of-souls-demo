extends SceneTree

func _initialize() -> void:
	for track in ["hall_theme", "point_theme", "other_side_theme"]:
		var stream: AudioStream = load("res://assets/audio/music/%s.mp3" % track)
		var playback := stream.instantiate_playback()
		if not playback.has_method("mix_audio"):
			print("Audio decoder does not expose mix_audio")
			break
		playback.start()
		var total := 0.0
		var samples := 0
		for block in range(323):
			var audio: PackedVector2Array = playback.call("mix_audio", 1.0, 4096)
			for sample in audio:
				total += sample.length_squared()
				samples += 2
		print("MUSIC_RMS ", track, " ", 10.0 * log(maxf(total / samples, 0.00000001)) / log(10.0))
	quit()
