extends SceneTree

func _init() -> void:
	print("--- TEST TABLE VIEW START ---")
	var sound_mgr = SoundManager.new()
	root.add_child(sound_mgr)

	var table = GameTable.new(GameRules.get_room("normal"))
	root.add_child(table)
	print("Table created and added to scene tree successfully.")

	assert(table.gold_box_panel != null, "gold_box_panel must exist")
	assert(table.deck_count_label != null, "deck_count_label must exist")
	assert(table.points_badge != null, "points_badge must exist")
	assert(table.seat_views.size() == 4, "4 seat views must exist")

	print("--- ALL TABLE VIEW CHECKS PASSED ---")
	quit(0)
