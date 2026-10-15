extends SceneTree

func _init() -> void:
	print("--- Testing Imported Audio Resources ---")
	var sfx_deal = load("res://assets/audio/sfx_deal.wav")
	var sfx_snap = load("res://assets/audio/sfx_snap.wav")
	var sfx_chime = load("res://assets/audio/sfx_gold_chime.wav")
	var sfx_fly = load("res://assets/audio/sfx_gold_fly.wav")
	var sfx_hu = load("res://assets/audio/sfx_hu.wav")
	var sfx_coin = load("res://assets/audio/sfx_coin.wav")
	var bgm = load("res://assets/audio/bgm.ogg")

	print("Deal: ", sfx_deal != null)
	print("Snap: ", sfx_snap != null)
	print("Chime: ", sfx_chime != null)
	print("Fly: ", sfx_fly != null)
	print("Hu: ", sfx_hu != null)
	print("Coin: ", sfx_coin != null)
	print("BGM: ", bgm != null)
	quit()
