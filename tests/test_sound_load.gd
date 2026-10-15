extends SceneTree

func _init() -> void:
	print("--- Testing Audio Loading ---")
	var ogg = AudioStreamOggVorbis.load_from_file("res://assets/audio/bgm.ogg")
	if ogg != null:
		print("SUCCESS: loaded bgm.ogg, length = ", ogg.get_length())
	else:
		print("FAILED to load bgm.ogg")

	var wav_file = FileAccess.open("res://assets/audio/sfx_deal.wav", FileAccess.READ)
	if wav_file != null:
		print("SUCCESS: file open sfx_deal.wav, size = ", wav_file.get_length())
		wav_file.close()
	else:
		print("FAILED to open sfx_deal.wav")

	quit()
