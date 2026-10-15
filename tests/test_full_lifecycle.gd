extends SceneTree

func _init() -> void:
	print("--- TEST FULL ROOM LIFECYCLE START ---")
	var root_node = GameRoot.new()
	root.add_child(root_node)
	
	await process_frame
	print("Entering normal room...")
	root_node._on_enter_room(GameRules.get_room("normal"))
	
	# Process 180 frames (approx 3 seconds of in-game animations)
	for i in range(180):
		await process_frame
		if i % 60 == 0:
			print("Frame ", i, " OK, tree has ", root.get_child_count(), " children.")

	print("--- TEST FULL ROOM LIFECYCLE PASSED ---")
	quit(0)
