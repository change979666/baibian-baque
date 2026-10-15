extends SceneTree

func _init() -> void:
	var table = GameTable.new(GameRules.get_room("normal"))
	root.add_child(table)
	await process_frame
	print("Calling _refresh_human_hand directly...")
	table._refresh_human_hand()
	print("Hand child count: ", table.hand_container.get_child_count())
	quit(0)
